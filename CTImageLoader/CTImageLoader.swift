import Foundation

public actor CTImageLoader: CTImageLoaderProtocol {
    public init() {}

    /// URLから画像をダウンロードしてデータを返す
    public func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw ImageLoaderError.downloadFailed
        }

        return data
    }
    
    /// ローカルの画像ファイルからデータを読み込む
    public func loadLocalImage(from url: URL) async throws -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImageLoaderError.fileNotFound
        }
        
        let fileExtension = url.pathExtension.lowercased()
        guard ["jpg", "jpeg", "png"].contains(fileExtension) else {
            throw ImageLoaderError.unsupportedFileType
        }
        
        return try Data(contentsOf: url)
    }
}
