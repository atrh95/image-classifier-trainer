import CatAPIClient
import CTDuplicateChecker
import CTFileManager
import CTImageLoader
import Foundation
import OvRClassification

private let fetchImagesCount = 10
private let defaultClassificationThreshold: Float = 0.85
private let defaultBatchSize = 10
private let defaultMaxRetries = 3

private struct ProcessingStats {
    var labelCounts: [String: Int] = [:]
    var totalProcessingTime: TimeInterval = 0
    var totalFetchedURLs = 0
    var failedDownloads = 0
    var invalidFormats = 0
    var duplicateImages = 0
    var processedAfterValidation = 0
    var skippedDueToMultipleFeatures = 0
    var noFeaturesDetected = 0 
}

private struct ImageProcessor {
    let imageLoader: CTImageLoaderProtocol
    let classifier: OvRClassifier
    let duplicateChecker: DuplicateCheckerProtocol
    let fileManager: CTFileManagerProtocol
    var stats: ProcessingStats
    let totalImages: Int
}

let semaphore = DispatchSemaphore(value: 0)

Task {
    do {
        let client = CatAPIClient()
        let fileManager = CTFileManager()
        let imageLoader = CTImageLoader()
        let classifier = try await OvRClassifier(
            fileManager: fileManager,
            imageLoader: imageLoader
        )
        let duplicateChecker = DuplicateChecker(
            fileManager: fileManager,
            imageLoader: imageLoader
        )

        try await runMainProcess(
            client: client,
            classifier: classifier,
            fileManager: fileManager,
            imageLoader: imageLoader,
            duplicateChecker: duplicateChecker
        )
    } catch {
        print("❌ エラーが発生しました: \(error)")
    }

    semaphore.signal()
}

semaphore.wait()
exit(0)

public func runMainProcess(
    client: CatAPIClient,
    classifier: OvRClassifier,
    fileManager: CTFileManagerProtocol,
    imageLoader: CTImageLoaderProtocol,
    duplicateChecker: DuplicateCheckerProtocol
) async throws {
    guard defaultBatchSize >= 10 else {
        throw NSError(
            domain: "InvalidParameter",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "batchSizeは10以上である必要があります"]
        )
    }

    // 重複チェッカーの初期化
    try await duplicateChecker.initializeHashes()

    var stats = ProcessingStats()
    let totalBatches = (fetchImagesCount + defaultBatchSize - 1) / defaultBatchSize

    print("🚀 画像URLの取得を開始...")
    print("\(fetchImagesCount)件の画像を\(defaultBatchSize)件ずつ\(totalBatches)バッチに分割して処理します")

    for batchIndex in 0 ..< totalBatches {
        let batchStartTime = Date()
        let startIndex = batchIndex * defaultBatchSize
        let endIndex = min(startIndex + defaultBatchSize, fetchImagesCount)
        let currentBatchSize = endIndex - startIndex

        print("\n📦 バッチ \(batchIndex + 1)/\(totalBatches) の処理を開始...")
        print("\(startIndex + 1)〜\(endIndex)件目の画像を処理します")

        // 画像のダウンロードと分類
        var urlModels: [CatImageURLModel] = []
        var retryCount = 0
        while urlModels.isEmpty, retryCount < defaultMaxRetries {
            do {
                urlModels = try await client.fetchImageURLs(requestedCount: currentBatchSize, batchSize: 10)
                stats.totalFetchedURLs += urlModels.count
            } catch {
                retryCount += 1
                if retryCount < defaultMaxRetries {
                    print("⚠️ URL取得に失敗しました。\(retryCount)回目のリトライを実行します...")
                    try await Task.sleep(nanoseconds: UInt64(3_000_000_000)) // 3秒待機
                } else {
                    print("❌ URL取得が\(defaultMaxRetries)回失敗しました。このバッチをスキップします。")
                    stats.failedDownloads += currentBatchSize
                    continue
                }
            }
        }

        if urlModels.isEmpty {
            continue
        }

        print("\(urlModels.count)件のURLを取得しました")
        print("🔍 画像の分類を開始...")

        var processor = ImageProcessor(
            imageLoader: imageLoader,
            classifier: classifier,
            duplicateChecker: duplicateChecker,
            fileManager: fileManager,
            stats: stats,
            totalImages: fetchImagesCount
        )

        for model in urlModels {
            guard let url = URL(string: model.url) else { continue }
            await processImage(url: url, processor: &processor)
        }

        stats = processor.stats

        let batchEndTime = Date()
        let batchProcessingTime = batchEndTime.timeIntervalSince(batchStartTime)
        stats.totalProcessingTime += batchProcessingTime

        printBatchProgress(
            batchIndex: batchIndex,
            totalBatches: totalBatches,
            batchProcessingTime: batchProcessingTime,
            totalProcessingTime: stats.totalProcessingTime,
            remainingBatches: totalBatches - (batchIndex + 1)
        )
    }

    print("\n🎉 自動分類が完了しました！")
    for (label, count) in stats.labelCounts.sorted(by: { $0.key < $1.key }) {
        print("\(label): \(count)枚")
    }

    print("\n🎉 処理が完了しました")
    print("処理時間: \(String(format: "%.1f", stats.totalProcessingTime))秒")
    print("URL取得数: \(stats.totalFetchedURLs)件")
    print("無効な形式を弾いた後に処理した枚数: \(stats.processedAfterValidation)件")
    print("- 保存した画像: \(stats.labelCounts.values.reduce(0, +))枚")
    print("- 重複により保存をスキップした枚数: \(stats.duplicateImages)件")
    print("- 複数の特徴を検知し、スキップした枚数: \(stats.skippedDueToMultipleFeatures)件")
    print("- 特徴が検出されなかった枚数: \(stats.noFeaturesDetected)件")

    if stats.failedDownloads > 0 || stats.invalidFormats > 0 {
        print("\n⏭️ スキップされた画像")
        if stats.failedDownloads > 0 {
            print("画像ダウンロード失敗: \(stats.failedDownloads)件")
        }
        if stats.invalidFormats > 0 {
            print("無効な形式: \(stats.invalidFormats)件")
        }
    }
}

private func processImage(
    url: URL,
    processor: inout ImageProcessor
) async {
    print("----------------------------------------")
    print("\(url)を処理中...")

    // 画像をダウンロード
    var imageData: Data?
    var retryCount = 0
    while imageData == nil, retryCount < defaultMaxRetries {
        do {
            imageData = try await processor.imageLoader.downloadImage(from: url)
        } catch {
            retryCount += 1
            if retryCount < defaultMaxRetries {
                print("⚠️ 画像のダウンロードに失敗しました。\(retryCount)回目のリトライを実行します...")
                try? await Task.sleep(nanoseconds: UInt64(3_000_000_000)) // 3秒待機
            } else {
                print("❌ 画像のダウンロードが\(defaultMaxRetries)回失敗しました。スキップします。")
                processor.stats.failedDownloads += 1
                print("----------------------------------------")
                return
            }
        }
    }

    guard let imageData else {
        processor.stats.failedDownloads += 1
        print("----------------------------------------")
        return
    }

    // 画像の拡張子を検証
    let allowedExtensions = ["jpg", "jpeg", "png"]
    let fileExtension = url.pathExtension.lowercased()
    guard allowedExtensions.contains(fileExtension) else {
        print("⚠️ 無効な形式の画像です \(url.lastPathComponent))")
        processor.stats.invalidFormats += 1
        print("----------------------------------------")
        return
    }

    // 無効な形式を弾いた後に処理した枚数をカウント
    processor.stats.processedAfterValidation += 1

    // 分類を実行
    do {
        let features = try await processor.classifier.getThresholdedFeatures(
            data: imageData,
            threshold: defaultClassificationThreshold
        )
        
        // 閾値を超えた特徴が1つだけの場合のみ保存
        if features.count == 1,
           let feature = features.first {
            // 重複チェックを実行
            if try await processor.duplicateChecker.checkDuplicate(
                imageData: imageData,
                fileName: url.lastPathComponent,
                label: feature.label
            ) {
                // 未確認データセットに保存
                try await processor.fileManager.saveImage(
                    imageData,
                    fileName: url.lastPathComponent,
                    label: feature.label
                )
                await processor.duplicateChecker.addHash(imageData: imageData)
                // 最終的な集計のために保存した枚数をカウント
                processor.stats.labelCounts[feature.label, default: 0] += 1
            } else {
                // printはduplicateCheckerで行う
                processor.stats.duplicateImages += 1
            }
        } else if features.count > 1 {
            // 閾値を超えた特徴が複数ある場合のみカウント
            print("⚠️ 閾値を超えた特徴が複数あるため、保存をスキップ")
            for feature in features.sorted(by: { $0.label < $1.label }) {
                print("- \(feature.label): \(String(format: "%.3f", feature.confidence))")
            }
            processor.stats.skippedDueToMultipleFeatures += 1
        } else {
            // 特徴が検出されなかった場合
            processor.stats.noFeaturesDetected += 1
        }
    } catch {
        print("❌ 分類に失敗しました: \(error)")
    }
    print("----------------------------------------")
}

private func printBatchProgress(
    batchIndex: Int,
    totalBatches: Int,
    batchProcessingTime: TimeInterval,
    totalProcessingTime: TimeInterval,
    remainingBatches: Int
) {
    print("✅ バッチ \(batchIndex + 1)/\(totalBatches) の処理が完了しました")
    print("このバッチの処理時間: \(String(format: "%.1f", batchProcessingTime))秒")
    
    // 最後のバッチ以外の場合のみ時刻予想を表示
    if remainingBatches > 0 {
        // 平均バッチ処理時間を計算
        let averageBatchTime = totalProcessingTime / Double(batchIndex + 1)
        let estimatedRemainingTime = averageBatchTime * Double(remainingBatches)

        // 予測終了時刻を計算
        let estimatedEndTime = Date().addingTimeInterval(estimatedRemainingTime)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let estimatedEndTimeString = dateFormatter.string(from: estimatedEndTime)

        // 残り時間をHH:MM:SS形式に変換
        let hours = Int(estimatedRemainingTime) / 3600
        let minutes = (Int(estimatedRemainingTime) % 3600) / 60
        let seconds = Int(estimatedRemainingTime) % 60
        let remainingTimeString = String(format: "%d時間%d分%d秒", hours, minutes, seconds)

        print("予測終了時刻: \(estimatedEndTimeString) (残り\(remainingTimeString))")
    }
}
