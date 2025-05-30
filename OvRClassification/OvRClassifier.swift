import CoreGraphics
import CoreML
import Foundation
import Vision

actor OvRClassifier {
    private struct ModelContainer: @unchecked Sendable {
        let visionModel: VNCoreMLModel
        let modelFileName: String
        let request: VNCoreMLRequest
    }

    private var models: [ModelContainer] = []
    private let enableLogging: Bool
    private let fileManager: ICTFileManager

    init(modelsDirectory: String = "OvRModels", enableLogging: Bool = true) async throws {
        self.enableLogging = enableLogging
        fileManager = ICTFileManager(baseDirectory: modelsDirectory, enableLogging: enableLogging)

        // .mlmodelcファイルの検索
        let modelFileURLs = try await fileManager.findModelFiles(in: modelsDirectory)
        guard !modelFileURLs.isEmpty else {
            if enableLogging {
                print("[OvRClassifier] [Error] モデルディレクトリ内に.mlmodelcファイルが存在しません")
            }
            throw ClassificationError.modelNotLoaded
        }

        // モデルのロード
        let loadedModels = try await loadModels(from: modelFileURLs)
        guard !loadedModels.isEmpty else {
            throw ClassificationError.modelNotLoaded
        }

        // 最終的なモデル配列を設定
        models = loadedModels

        if enableLogging {
            print(
                "[OvRClassifier] [Info] \(models.count)個のOvRモデルをロード完了: \(models.map(\.modelFileName).joined(separator: ", "))"
            )
        }
    }

    /// モデルファイルからVisionモデルとリクエストを並列にロード
    private func loadModels(from modelFileURLs: [URL]) async throws -> [ModelContainer] {
        var collectedContainers: [ModelContainer] = []

        try await withThrowingTaskGroup(of: ModelContainer.self) { group in
            for url in modelFileURLs {
                group.addTask {
                    try await self.loadModel(from: url)
                }
            }

            // 完了したタスクの結果を収集
            for try await container in group {
                collectedContainers.append(container)
            }
        }

        return collectedContainers
    }

    /// 個別のモデルファイルからVisionモデルとリクエストをロード
    private func loadModel(from url: URL) async throws -> ModelContainer {
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

    func classifyImage(_ imageData: Data) async throws -> [ClassificationResult] {
        var results: [ClassificationResult] = []

        try await withThrowingTaskGroup(
            of: (modelId: String, observations: [VNClassificationObservation]?)
                .self
        ) { group in
            for container in self.models {
                group.addTask {
                    do {
                        let handler = VNImageRequestHandler(data: imageData, options: [:])
                        try handler.perform([container.request])
                        guard let observations = container.request.results as? [VNClassificationObservation] else {
                            if self.enableLogging {
                                print("[OvRClassifier] [Warning] モデル\(container.modelFileName)の結果が不正な形式")
                            }
                            return (container.modelFileName, nil)
                        }
                        return (container.modelFileName, observations)
                    } catch {
                        if self.enableLogging {
                            print(
                                "[OvRClassifier] [Error] モデル \(container.modelFileName) のVisionリクエスト失敗: \(error.localizedDescription)"
                            )
                        }
                        throw ClassificationError.classificationFailed
                    }
                }
            }

            for try await result in group {
                guard let observations = result.observations else { continue }

                for observation in observations where observation.identifier != "Rest" {
                    results.append(ClassificationResult(
                        label: observation.identifier,
                        confidence: observation.confidence
                    ))
                }
            }
        }

        return results
    }
}
