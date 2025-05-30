import Foundation

actor ICTImageLoader {
    private let enableLogging: Bool

    init(enableLogging: Bool = true) {
        self.enableLogging = enableLogging
    }

    /// URLから画像をダウンロード
    func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw ImageLoaderError.downloadFailed
        }

        if enableLogging {
            print("[ICTImageLoader] [Info] 画像をダウンロード: \(url.lastPathComponent)")
        }

        return data
    }
}
