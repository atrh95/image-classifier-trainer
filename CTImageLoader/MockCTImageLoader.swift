import Foundation

public final class MockCTImageLoader: CTImageLoaderProtocol {
    private let sampleImagesDirectory: URL
    public var testImageURL: URL {
        sampleImagesDirectory.appendingPathComponent("MTU1MDA0NA.jpg")
    }

    public init() {
        // サンプル画像ディレクトリのパスを設定
        let currentFileURL = URL(fileURLWithPath: #filePath)
        sampleImagesDirectory = currentFileURL
            .deletingLastPathComponent() // CTImageLoader
            .appendingPathComponent("SampleImage")

        // ディレクトリが存在しない場合は作成
        try? FileManager.default.createDirectory(at: sampleImagesDirectory, withIntermediateDirectories: true)
    }

    public func downloadImage(from _: URL) async throws -> Data {
        // サンプル画像ディレクトリから画像を読み込む
        guard let imageData = try? Data(contentsOf: testImageURL) else {
            throw ImageLoaderError.sampleImageNotFound
        }

        return imageData
    }
}
