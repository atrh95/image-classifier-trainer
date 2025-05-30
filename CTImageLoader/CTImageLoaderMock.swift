import CTFileManager
import Foundation

public final class CTImageLoaderMock: CTImageLoaderProtocol {
    private let fileManager: CTFileManagerProtocol
    private let sampleImagesDirectory: URL
    private let sampleImageName = "MTU1MDA0NA.jpg"

    public init(fileManager: CTFileManagerProtocol) {
        self.fileManager = fileManager

        // サンプル画像ディレクトリのパスを設定
        let currentFileURL = URL(fileURLWithPath: #filePath)
        sampleImagesDirectory = currentFileURL
            .deletingLastPathComponent() // CTImageLoader
            .deletingLastPathComponent() // root
            .appendingPathComponent("SampleImage")

        // ディレクトリが存在しない場合は作成
        try? FileManager.default.createDirectory(at: sampleImagesDirectory, withIntermediateDirectories: true)
    }

    public func downloadAndSaveImage(from url: URL, label: String) async throws {
        // サンプル画像ディレクトリから画像を読み込む
        let fileURL = sampleImagesDirectory.appendingPathComponent(sampleImageName)

        guard let imageData = try? Data(contentsOf: fileURL) else {
            throw ImageLoaderError.sampleImageNotFound
        }

        // 画像データを保存
        try await fileManager.saveImage(imageData, fileName: url.lastPathComponent, label: label)
    }
}
