import CoreGraphics
import CoreML
import Foundation
import ICTShared
import Vision

let fetchImageCount = 5
let classificationThreshold: Float = 0.85

let semaphore = DispatchSemaphore(value: 0)

Task {
    let classifier = try await OvRClassifier()
    let fileManager = ICTFileManager()
    let catAPI = CatAPIClient()

    print("分類処理を開始します...")
    let imageURLs = try await catAPI.fetchCatImageURLs(count: fetchImageCount)

    var labelCounts: [String: Int] = [:]

    for url in imageURLs {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let results = try await classifier.classifyImage(data)
            if let bestResult = results.max(by: { $0.confidence < $1.confidence }) {
                try await fileManager.downloadAndSaveImage(from: url, label: bestResult.label)
                labelCounts[bestResult.label, default: 0] += 1
            }
        } catch {
            print("エラー: \(error)")
        }
    }

    print("分類結果:")
    for (label, count) in labelCounts.sorted(by: { $0.key < $1.key }) {
        print("  \(label): \(count)枚")
    }

    semaphore.signal()
}

semaphore.wait()
