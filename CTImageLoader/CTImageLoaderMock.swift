import Foundation

public final class CTImageLoaderMock: CTImageLoaderProtocol {
    private let sampleImagesDirectory: URL
    private let sampleImageName = "MTU1MDA0NA.jpg"

    public init() {
        // サンプル画像ディレクトリのパスを設定
        let currentFileURL = URL(fileURLWithPath: #filePath)
        sampleImagesDirectory = currentFileURL
            .deletingLastPathComponent() // CTImageLoader
            .deletingLastPathComponent() // root
            .appendingPathComponent("SampleImage")

        // ディレクトリが存在しない場合は作成
        try? FileManager.default.createDirectory(at: sampleImagesDirectory, withIntermediateDirectories: true)
    }

    public func downloadImage(from url: URL) async throws -> Data {
        // サンプル画像ディレクトリから画像を読み込む
        let fileURL = sampleImagesDirectory.appendingPathComponent(sampleImageName)

        guard let imageData = try? Data(contentsOf: fileURL) else {
            throw ImageLoaderError.sampleImageNotFound
        }

        return imageData
    }
}
