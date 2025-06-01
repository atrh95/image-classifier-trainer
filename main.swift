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
    var totalProcessedImages = 0
    var totalProcessingTime: TimeInterval = 0
    var totalProcessedCount = 0
    var totalFetchedURLs = 0
    var failedURLFetches = 0
    var failedDownloads = 0
    var invalidFormats = 0
    var duplicateImages = 0
    var multipleFeatures = 0  // 閾値を超えた特徴が複数ある場合のカウント
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
                    stats.failedURLFetches += currentBatchSize
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
    // 分類結果の集計を表示
    for (label, count) in stats.labelCounts {
        print("\(label): \(count)枚")
    }
    
    print("自動分類を行った画像は Dataset/Unverified ディレクトリに保存されました。")
    print("画像を確認し、分類が正しい場合は Dataset/Verified ディレクトリに移動してください。")
    
    // 処理の完了
    print("\n🎉 処理が完了しました")
    print("処理時間: \(String(format: "%.1f", stats.totalProcessingTime))秒")
    print("URL取得数: \(stats.totalFetchedURLs)件")
    print("処理した画像: \(stats.totalProcessedCount)枚")
    print("保存した画像: \(stats.labelCounts.values.reduce(0, +))枚")
    
    if !stats.labelCounts.isEmpty {
        print("\n📁 保存された画像の内訳")
        for (label, count) in stats.labelCounts.sorted(by: { $0.key < $1.key }) {
            print("\(label): \(count)枚")
        }
    }
    
    if stats.failedURLFetches > 0 || stats.failedDownloads > 0 || 
       stats.invalidFormats > 0 || stats.duplicateImages > 0 || 
       stats.multipleFeatures > 0 {
        print("\n⏭️ スキップされた画像")
        if stats.failedURLFetches > 0 {
            print("URL取得失敗: \(stats.failedURLFetches)件")
        }
        if stats.failedDownloads > 0 {
            print("画像ダウンロード失敗: \(stats.failedDownloads)件")
        }
        if stats.invalidFormats > 0 {
            print("無効な形式: \(stats.invalidFormats)件")
        }
        if stats.duplicateImages > 0 {
            print("重複画像: \(stats.duplicateImages)件")
        }
        if stats.multipleFeatures > 0 {
            print("閾値未達: \(stats.multipleFeatures)件")
        }
    }
}

private func processImage(
    url: URL,
    processor: inout ImageProcessor
) async {
    processor.stats.totalProcessedImages += 1
    print("\(url)を処理中...(\(processor.stats.totalProcessedImages)/\(processor.totalImages)件目)")
    
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
                return
            }
        }
    }
    
    guard let imageData else { 
        processor.stats.failedDownloads += 1
        return 
    }
    
    // 画像の拡張子を検証
    let allowedExtensions = ["jpg", "jpeg", "png"]
    let fileExtension = url.pathExtension.lowercased()
    guard allowedExtensions.contains(fileExtension) else {
        print("⚠️ 無効な形式の画像です \(url.lastPathComponent))")
        processor.stats.invalidFormats += 1
        return
    }
    
    // 分類を実行
    do {
        if let feature = try await processor.classifier.classifyImage(
            data: imageData,
            threshold: defaultClassificationThreshold
        ) {
            // 重複チェックを実行
            if try await processor.duplicateChecker.checkDuplicate(
                imageData: feature.imageData,
                fileName: url.lastPathComponent,
                label: feature.label
            ) {
                // 未確認データセットに保存
                try await processor.fileManager.saveImage(
                    feature.imageData,
                    fileName: url.lastPathComponent,
                    label: feature.label
                )
                // 保存成功時にハッシュを追加
                await processor.duplicateChecker.addHash(imageData: feature.imageData)
                // 最終的な集計のためにカウント
                processor.stats.labelCounts[feature.label, default: 0] += 1
                processor.stats.totalProcessedCount += 1
            } else {
                // printはduplicateCheckerで行う
                processor.stats.duplicateImages += 1
            }
        } else {
            processor.stats.multipleFeatures += 1
        }
    } catch {
        print("⚠️ 画像の分類に失敗しました: \(error.localizedDescription)")
        processor.stats.failedDownloads += 1
        return
    }
}

private func printBatchProgress(
    batchIndex: Int,
    totalBatches: Int,
    batchProcessingTime: TimeInterval,
    totalProcessingTime: TimeInterval,
    remainingBatches: Int
) {
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
    
    print("✅ バッチ \(batchIndex + 1)/\(totalBatches) の処理が完了しました")
    print("このバッチの処理時間: \(String(format: "%.1f", batchProcessingTime))秒")
    print("予測終了時刻: \(estimatedEndTimeString) (残り\(remainingTimeString))")
}

