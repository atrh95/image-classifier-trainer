import CatAPIClient
import CTFileManager
import CTImageLoader
import Foundation
import OvRClassification

private let defaultFetchImageCount = 1000
private let defaultClassificationThreshold: Float = 0.85
private let defaultBatchSize = 200
private let defaultMaxRetries = 3

public func runMainProcess(
    client: CatAPIClient,
    classifier: OvRClassifier,
    fileManager: CTFileManagerProtocol,
    imageLoader: CTImageLoaderProtocol,
    duplicateChecker: DuplicateCheckerProtocol
) async throws {
    guard defaultBatchSize >= 10 else {
        throw NSError(domain: "InvalidParameter", code: -1, userInfo: [NSLocalizedDescriptionKey: "batchSizeは10以上である必要があります"])
    }
    
    // 重複チェッカーの初期化
    try await duplicateChecker.initializeHashes()
    
    var labelCounts: [String: Int] = [:]
    let totalBatches = (defaultFetchImageCount + defaultBatchSize - 1) / defaultBatchSize
    var totalProcessedImages = 0
    var totalProcessingTime: TimeInterval = 0
    var totalProcessedCount = 0
    var failedImages = 0

    print("🚀 画像URLの取得を開始...")
    print("   \(defaultFetchImageCount)件の画像を\(defaultBatchSize)件ずつ\(totalBatches)バッチに分割して処理します")

    for batchIndex in 0 ..< totalBatches {
        let batchStartTime = Date()
        let startIndex = batchIndex * defaultBatchSize
        let endIndex = min(startIndex + defaultBatchSize, defaultFetchImageCount)
        let currentBatchSize = endIndex - startIndex

        print("\n📦 バッチ \(batchIndex + 1)/\(totalBatches) の処理を開始...")
        print("   \(startIndex + 1)〜\(endIndex)件目の画像を処理します")

        // 画像のダウンロードと分類
        var urlModels: [CatImageURLModel] = []
        var retryCount = 0
        while urlModels.isEmpty && retryCount < defaultMaxRetries {
            do {
                urlModels = try await client.fetchImageURLs(requestedCount: currentBatchSize, batchSize: 10)
            } catch {
                retryCount += 1
                if retryCount < defaultMaxRetries {
                    print("   ⚠️ URL取得に失敗しました。\(retryCount)回目のリトライを実行します...")
                    try await Task.sleep(nanoseconds: UInt64(3_000_000_000)) // 3秒待機
                } else {
                    print("   ❌ URL取得が\(defaultMaxRetries)回失敗しました。このバッチをスキップします。")
                    continue
                }
            }
        }
        
        if urlModels.isEmpty {
            continue
        }
        
        print("   \(urlModels.count)件のURLを取得しました")

        print("🔍 画像の分類を開始...")
        for (_, model) in urlModels.enumerated() {
            totalProcessedImages += 1
            print("   \(model.url)を処理中...(\(totalProcessedImages)/\(defaultFetchImageCount)件目)")
            guard let url = URL(string: model.url) else { continue }

            // 画像をダウンロード（リトライ付き）
            var imageData: Data?
            retryCount = 0
            while imageData == nil && retryCount < defaultMaxRetries {
                do {
                    imageData = try await imageLoader.downloadImage(from: url)
                } catch {
                    retryCount += 1
                    if retryCount < defaultMaxRetries {
                        print("   ⚠️ 画像のダウンロードに失敗しました。\(retryCount)回目のリトライを実行します...")
                        try await Task.sleep(nanoseconds: UInt64(3_000_000_000)) // 3秒待機
                    } else {
                        print("   ❌ 画像のダウンロードが\(defaultMaxRetries)回失敗しました。スキップします。")
                        failedImages += 1
                        break
                    }
                }
            }

            guard let imageData = imageData else { continue }

            // 分類を実行
            do {
                if let feature = try await classifier.classifyImage(
                    data: imageData,
                    threshold: defaultClassificationThreshold
                ) {
                    // 重複チェックを実行
                    if try await duplicateChecker.checkDuplicate(
                        imageData: feature.imageData,
                        fileName: url.lastPathComponent,
                        label: feature.label
                    ) {
                        // 未確認データセットに保存
                        try await fileManager.saveImage(
                            feature.imageData,
                            fileName: url.lastPathComponent,
                            label: feature.label
                        )
                        // 保存成功時にハッシュを追加
                        await duplicateChecker.addHash(imageData: feature.imageData)
                        // 最終的な集計のためにカウント
                        labelCounts[feature.label, default: 0] += 1
                    } else {
                        print("   ⚠️ 重複のため保存をスキップ: \(url.lastPathComponent) (\(feature.label))")
                    }
                }
            } catch {
                print("   ⚠️ 画像の分類に失敗しました: \(error.localizedDescription)")
                failedImages += 1
                continue
            }
            
            totalProcessedCount += 1
        }

        let batchEndTime = Date()
        let batchProcessingTime = batchEndTime.timeIntervalSince(batchStartTime)
        totalProcessingTime += batchProcessingTime

        // 平均バッチ処理時間を計算
        let averageBatchTime = totalProcessingTime / Double(batchIndex + 1)
        let remainingBatches = totalBatches - (batchIndex + 1)
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
        print("   このバッチの処理時間: \(String(format: "%.1f", batchProcessingTime))秒")
        print("   予測終了時刻: \(estimatedEndTimeString) (残り\(remainingTimeString))")
    }

    print("\n🎉 自動分類が完了しました！")
    // 分類結果の集計を表示
    for (label, count) in labelCounts {
        print("\(label): \(count)枚")
    }

    print("自動分類を行った画像は Dataset/Unverified ディレクトリに保存されました。")
    print("画像を確認し、分類が正しい場合は Dataset/Verified ディレクトリに移動してください。")

    // 処理の完了
    print("\n✅ 処理が完了しました")
    print("   処理時間: \(String(format: "%.1f", totalProcessingTime))秒")
    print("   処理した画像: \(totalProcessedCount)枚")
    print("   保存した画像: \(labelCounts.values.reduce(0, +))枚")
    print("   失敗した画像: \(failedImages)枚")
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
        let duplicateChecker = DuplicateChecker(fileManager: fileManager)
        
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
