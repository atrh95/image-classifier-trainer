import CoreGraphics
import CoreML
import CTFileManager
import CTImageLoader
import Foundation
import Vision

private struct ModelContainer: @unchecked Sendable {
    let visionModel: VNCoreMLModel
    let modelFileName: String
    let request: VNCoreMLRequest
}

public actor OvRClassifier {
    private var models: [ModelContainer] = []
    private let fileManager: CTFileManagerProtocol
    private let imageLoader: CTImageLoaderProtocol

    private var modelDirectoryURL: URL {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("OvRModels")
    }

    public init(
        fileManager: CTFileManagerProtocol,
        imageLoader: CTImageLoaderProtocol
    ) async throws {
        self.fileManager = fileManager
        self.imageLoader = imageLoader

        // モデルのロード
        let loadedModels = try await loadMLModels()
        guard !loadedModels.isEmpty else {
            throw ClassificationError.modelNotFound
        }

        models = loadedModels
    }

    /// URLから画像をダウンロードし、分類を行い、閾値を超えた場合は保存する
    public func classifyImageFromURL(
        from url: URL,
        threshold: Float
    ) async throws -> DetectedFeature? {
        // 画像データのダウンロード
        let data = try await imageLoader.downloadImage(from: url)

        // 全てのモデルで画像を分類し、閾値を超えた特徴が1つだけの場合のみ結果を返す
        if let feature = try await classifySingleImage(data, probabilityThreshold: threshold) {
            return feature
        }
        return nil
    }

    private func classifySingleImage(
        _ imageData: Data,
        probabilityThreshold threshold: Float
    ) async throws -> DetectedFeature? {
        var detectedFeatures: [(label: String, confidence: Float)] = []

        try await withThrowingTaskGroup(
            of: (modelId: String, observations: [(featureName: String, confidence: Float)]?)
                .self
        ) { group in
            for container in self.models {
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

            for try await result in group {
                guard let mappedObservations = result.observations else { continue }

                // 閾値を超えた特徴を収集（Restを含む）
                for observation in mappedObservations {
                    detectedFeatures.append((label: observation.featureName, confidence: observation.confidence))
                }
            }
        }

        // 分類結果を表示
        print("   分類結果:")
        let sortedFeatures = detectedFeatures.sorted { $0.label < $1.label }
        for feature in sortedFeatures {
            if feature.label != "Rest" {
                let checkmark = feature.confidence >= threshold ? "✅" : "  "
                print("     \(checkmark) \(feature.label): \(String(format: "%.3f", feature.confidence))")
            }
        }
        print("----------------------------------------")

        // 閾値を超えた特徴をフィルタリング
        let thresholdedFeatures = detectedFeatures.filter { $0.confidence >= threshold }
        let nonRestThresholdedFeatures = thresholdedFeatures.filter { $0.label != "Rest" }

        // 閾値を超えた特徴が1つだけの場合のみ結果を返す
        guard nonRestThresholdedFeatures.count == 1,
              let feature = nonRestThresholdedFeatures.first
        else {
            return nil
        }

        return DetectedFeature(
            label: feature.label,
            confidence: feature.confidence,
            imageData: imageData
        )
    }

    /// モデルファイルからVisionモデルとリクエストを並列にロード
    private func loadMLModels() async throws -> [ModelContainer] {
        var collectedContainers: [ModelContainer] = []

        // モデルディレクトリ内の.mlmodelcファイルを取得
        let modelURLs = try await fileManager.getModelFiles(in: modelDirectoryURL)

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
                            for device in allDevices {
                                if device.description.contains("MLCPUComputeDevice") {
                                    request.setComputeDevice(.some(device), for: .main)
                                    break
                                }
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
