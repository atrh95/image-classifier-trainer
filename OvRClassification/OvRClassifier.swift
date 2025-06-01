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

    /// 画像データを分類し、閾値を超えた特徴のリストを返す
    public func getThresholdedFeatures(
        data imageData: Data,
        threshold: Float
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
            // 全てのモデルを並列に実行
            for container in models {
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

        return thresholdedFeatures
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
