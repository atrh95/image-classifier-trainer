import CoreGraphics
import CoreML
import Foundation
import SLFileManager
import SLImageLoader
import Vision

private struct ModelContainer: @unchecked Sendable {
    let visionModel: VNCoreMLModel
    let modelFileName: String
    let request: VNCoreMLRequest
}

public actor SLClassifier {
    public static let ovrDefaultThreshold: Float = 0.95

    private var ovrModels: [ModelContainer] = []
    private var ovoModels: [ModelContainer] = []
    private let fileManager: SLFileManagerProtocol
    private let imageLoader: SLImageLoaderProtocol

    private var ovrModelDirectoryURL: URL {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("OvRModels")
    }

    private var ovoModelDirectoryURL: URL {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("OvOModels")
    }

    public init(
        fileManager: SLFileManagerProtocol,
        imageLoader: SLImageLoaderProtocol
    ) async throws {
        self.fileManager = fileManager
        self.imageLoader = imageLoader

        // OvRモデルのロード
        let loadedOvRModels = try await loadModels(from: ovrModelDirectoryURL)
        guard !loadedOvRModels.isEmpty else {
            throw ClassificationError.modelNotFound
        }
        ovrModels = loadedOvRModels

        // OvOモデルのロード
        let loadedOvOModels = try await loadModels(from: ovoModelDirectoryURL)
        ovoModels = loadedOvOModels
    }

    /// 画像データを分類し、閾値を超えた特徴のリストを返す
    public func getThresholdedFeatures(
        data imageData: Data,
        threshold: Float = SLClassifier.ovrDefaultThreshold
    ) async throws -> [(label: String, confidence: Float)] {
        // 閾値を0に設定して全ての結果を取得
        let allFeatures = try await classifyImageWithThreshold(
            imageData: imageData,
            threshold: 0.0
        )

        // 全ての分類結果を表示
        print("分類結果:")
        let sortedFeatures = allFeatures.sorted { $0.label < $1.label }
        for feature in sortedFeatures {
            let checkmark = feature.confidence >= threshold ? "✅ " : ""
            print("\(checkmark)\(feature.label): \(String(format: "%.3f", feature.confidence))")
        }

        // 閾値を超えた特徴のみを返す
        return allFeatures.filter { $0.confidence >= threshold }
    }

    /// 画像データを分類し、閾値を超えた特徴のリストを返す
    private func classifyImageWithThreshold(
        imageData: Data,
        threshold: Float
    ) async throws -> [(label: String, confidence: Float)] {
        var thresholdedFeatures: [(label: String, confidence: Float)] = []

        try await withThrowingTaskGroup(
            of: (modelId: String, observations: [(featureName: String, confidence: Float)]?)
                .self
        ) { group in
            // 全てのOvRモデルを並列に実行
            for container in ovrModels {
                group.addTask {
                    do {
                        let handler = VNImageRequestHandler(data: imageData, options: [:])
                        try handler.perform([container.request])
                        guard let observations = container.request.results as? [VNClassificationObservation] else {
                            return (container.modelFileName, nil)
                        }
                        let mappedObservations = observations.map { (
                            featureName: $0.identifier,
                            confidence: $0.confidence
                        ) }
                        return (container.modelFileName, mappedObservations)
                    } catch {
                        throw ClassificationError.classificationFailed
                    }
                }
            }

            // 全ての結果を収集
            for try await result in group {
                guard let mappedObservations = result.observations else { continue }
                for observation in mappedObservations where observation.featureName != "rest" {
                    if observation.confidence >= threshold {
                        thresholdedFeatures.append((label: observation.featureName, confidence: observation.confidence))
                    }
                }
            }
        }

        // mouth_openのみが検出された場合の特別処理
        if let mouthOpenIndex = thresholdedFeatures.firstIndex(where: { $0.label == "mouth_open" }),
           thresholdedFeatures.count == 1 {
            await checkMouthOpenWithOvO(
                thresholdedFeatures: &thresholdedFeatures,
                mouthOpenIndex: mouthOpenIndex,
                imageData: imageData
            )
        }

        return thresholdedFeatures
    }

    /// OvOモデルでmouth_openの再判定を行う
    private func checkMouthOpenWithOvO(
        thresholdedFeatures: inout [(label: String, confidence: Float)],
        mouthOpenIndex: Int,
        imageData: Data
    ) async {
        if let ovoContainer = ovoModels.first(where: { $0.modelFileName.contains("OvO_mouth_open_vs_safe") }) {
            do {
                let handler = VNImageRequestHandler(data: imageData, options: [:])
                try handler.perform([ovoContainer.request])
                if let observations = ovoContainer.request.results as? [VNClassificationObservation],
                   let safeObservation = observations.first(where: { $0.identifier.lowercased() == "safe" }),
                   let mouthOpenObservation = observations
                   .first(where: { $0.identifier.lowercased() == "mouth_open" }) {
                    // 信頼度の高い方のクラスを採用
                    if safeObservation.confidence > mouthOpenObservation.confidence {
                        thresholdedFeatures[mouthOpenIndex].confidence = 0
                        print("[SLClassifier] [Info] OvOモデルによりsafeと判定され、mouth_openの信頼度を0に設定")
                    }
                }
            } catch {
                print("[SLClassifier] [Warning] OvOモデルの検証に失敗: \(error.localizedDescription)")
            }
        }
    }

    /// モデルファイルからVisionモデルとリクエストを並列にロード
    private func loadModels(from directoryURL: URL) async throws -> [ModelContainer] {
        var collectedContainers: [ModelContainer] = []

        // モデルディレクトリ内の.mlmodelcファイルを取得
        let modelURLs = try await fileManager.getModelFiles(in: directoryURL)

        guard !modelURLs.isEmpty else {
            throw ClassificationError.modelNotFound
        }

        try await withThrowingTaskGroup(of: ModelContainer.self) { group in
            for url in modelURLs {
                group.addTask {
                    // MLModelConfigurationの設定
                    let config = MLModelConfiguration()
                    config.computeUnits = .all

                    // モデルのロードと設定
                    let mlModel = try MLModel(contentsOf: url, configuration: config)
                    let visionModel = try VNCoreMLModel(for: mlModel)

                    // Visionリクエストの設定
                    let request = VNCoreMLRequest(model: visionModel)
                    #if targetEnvironment(simulator)
                        if #available(iOS 17.0, *) {
                            let allDevices = MLComputeDevice.allComputeDevices
                            for device in allDevices where device.description.contains("MLCPUComputeDevice") {
                                request.setComputeDevice(.some(device), for: .main)
                                break
                            }
                        } else {
                            request.usesCPUOnly = true
                        }
                    #endif
                    request.imageCropAndScaleOption = .scaleFit

                    return ModelContainer(
                        visionModel: visionModel,
                        modelFileName: url.deletingPathExtension().lastPathComponent,
                        request: request
                    )
                }
            }

            // 完了したタスクの結果を収集
            for try await container in group {
                collectedContainers.append(container)
            }
        }

        return collectedContainers
    }
}
