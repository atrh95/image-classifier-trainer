import CatAPIClient
import CTFileManager
import CTImageLoader
import Foundation
import OvRClassification

public func runMainProcess(
    client: CatAPIClient,
    classifier: OvRClassifier,
    fileManager: CTFileManagerProtocol,
    imageLoader: CTImageLoaderProtocol,
    fetchImageCount: Int = 100000,
    classificationThreshold: Float = 0.85,
    batchSize: Int = 100
) async throws {
    var labelCounts: [String: Int] = [:]
    let totalBatches = (fetchImageCount + batchSize - 1) / batchSize
    var totalProcessedImages = 0
    var totalProcessingTime: TimeInterval = 0

    print("🚀 画像URLの取得を開始...")
    print("   \(fetchImageCount)件の画像を\(batchSize)件ずつ\(totalBatches)バッチに分割して処理します")

    for batchIndex in 0..<totalBatches {
        let batchStartTime = Date()
        let startIndex = batchIndex * batchSize
        let endIndex = min(startIndex + batchSize, fetchImageCount)
        let currentBatchSize = endIndex - startIndex

        print("\n📦 バッチ \(batchIndex + 1)/\(totalBatches) の処理を開始...")
        print("   \(startIndex + 1)〜\(endIndex)件目の画像を処理します")

        // 画像のダウンロードと分類
        let urlModels = try await client.fetchImageURLs(requestedCount: currentBatchSize, batchSize: 10)
        print("   \(urlModels.count)件のURLを取得しました")

        print("🔍 画像の分類を開始...")
        for (index, model) in urlModels.enumerated() {
            totalProcessedImages += 1
            print("   \(model.url)を処理中...(\(totalProcessedImages)/\(fetchImageCount)件目)")
            guard let url = URL(string: model.url) else { continue }

            // 画像をダウンロード
            let imageData = try await imageLoader.downloadImage(from: url)

            // 分類を実行
            if let feature = try await classifier.classifyImageFromURL(
                from: url,
                threshold: classificationThreshold
            ) {
                // 確認済みと未確認の両方のデータセットで重複チェック
                let existsInVerified = await fileManager.fileExists(
                    fileName: url.lastPathComponent,
                    label: feature.label,
                    isVerified: true
                )
                let existsInUnverified = await fileManager.fileExists(
                    fileName: url.lastPathComponent,
                    label: feature.label,
                    isVerified: false
                )

                if !existsInVerified, !existsInUnverified {
                    // 未確認データセットに保存
                    try await fileManager.saveImage(
                        feature.imageData,
                        fileName: url.lastPathComponent,
                        label: feature.label
                    )
                    // 最終的な集計のためにカウント
                    labelCounts[feature.label, default: 0] += 1
                }
            }
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
    print("次回の分類時に重複確認が両方のディレクトリに対して行われます")
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

        try await runMainProcess(
            client: client,
            classifier: classifier,
            fileManager: fileManager,
            imageLoader: imageLoader
        )
    } catch {
        print("エラーが発生しました: \(error)")
    }
    semaphore.signal()
}

semaphore.wait()
