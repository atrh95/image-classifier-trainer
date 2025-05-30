import CTFileManager
import Foundation

public actor CTImageLoader {
    private let enableLogging: Bool
    private let fileManager: CTFileManager

    public init(fileManager: CTFileManager, enableLogging: Bool = true) {
        self.enableLogging = enableLogging
        self.fileManager = fileManager
    }

    /// URLから画像をダウンロードして人間によって未確認として保存
    public func downloadAndSaveImage(from url: URL, label: String) async throws {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw ImageLoaderError.downloadFailed
        }

        if enableLogging {
            print("[CTImageLoader] [Info] 画像をダウンロード: \(url.lastPathComponent)")
        }

        try await fileManager.saveImage(data, fileName: url.lastPathComponent, label: label, isVerified: false)
    }
}
