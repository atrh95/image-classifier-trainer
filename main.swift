import CatAPIClient
import CTFileManager
import Foundation
import OvRClassification

let fetchImageCount = 10
let classificationThreshold: Float = 0.85

let semaphore = DispatchSemaphore(value: 0)

Task {
    do {
        let client = CatAPIClient()
        let classifier = try await OvRClassifier()
        let fileManager = CTFileManager()
        var labelCounts: [String: Int] = [:]

        print("🚀 画像URLの取得を開始...")
        // 画像のダウンロードと分類
        let urlModels = try await client.fetchImageURLs(totalCount: fetchImageCount, batchSize: 10)
        print("   \(urlModels.count)件のURLを取得しました")

        print("🔍 画像の分類を開始...")
        for (index, model) in urlModels.enumerated() {
            print("   \(model.url)を処理中...(\(index + 1)/\(urlModels.count)件目)")
            guard let url = URL(string: model.url) else { continue }
            if let feature = try await classifier.classifyImageFromURLWithThreshold(
                from: url,
                threshold: classificationThreshold
            ) {
                // 確認済みと未確認の両方のデータセットで重複チェック
                let existsInVerified = await fileManager.fileExists(fileName: url.lastPathComponent, label: feature.label, isVerified: true)
                let existsInUnverified = await fileManager.fileExists(fileName: url.lastPathComponent, label: feature.label, isVerified: false)
                
                if !existsInVerified && !existsInUnverified {
                    // 未確認データセットに保存
                    try await fileManager.saveImage(
                        feature.imageData,
                        fileName: url.lastPathComponent,
                        label: feature.label,
                        isVerified: false
                    )
                    // 最終的な集計のためにカウント
                    labelCounts[feature.label, default: 0] += 1
                }
            }
        }

        print("🎉 自動分類が完了しました！")
        // 分類結果の集計を表示
        for (label, count) in labelCounts {
            print("\(label): \(count)枚")
        }
        
        print("自動分類を行った画像は Dataset/Unverified ディレクトリに保存されました。")
        print("画像を確認し、分類が正しい場合は Dataset/Verified ディレクトリに移動してください。")
        print("次回の分類時に重複確認が両方のディレクトリに対して行われます")
    } catch {
        print("エラーが発生しました: \(error)")
    }
    semaphore.signal()
}

semaphore.wait()
