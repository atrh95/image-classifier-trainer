import Foundation

public struct CatAPIClient: CatAPIClientProtocol {
    public init() {}

    public func fetchImageURLs(requestedCount: Int, batchSize: Int) async throws -> [CatImageURLModel] {
        var result: [CatImageURLModel] = []
        var pagesRetrieved = 0
        let allowedExtensions = ["jpg", "png", "jpeg"]
        var totalFetched = 0

        while result.count < requestedCount {
            guard let url =
                URL(
                    string: "https://api.thecatapi.com/v1/images/search?limit=\(batchSize)&page=\(pagesRetrieved)&order=Rand"
                )
            else {
                throw URLError(.badURL)
            }

            let request = URLRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            let catImages = try decoder.decode([CatImageURLModel].self, from: data)
            totalFetched += catImages.count

            // 許可された拡張子の画像のみをフィルタリング
            let filteredImages = catImages.filter { image in
                guard let url = URL(string: image.url) else { return false }
                let pathExtension = url.pathExtension.lowercased()
                return allowedExtensions.contains(pathExtension)
            }

            result += filteredImages
            pagesRetrieved += 1

            // ページを取得しても結果が増えない場合（全ての画像がフィルタリングされた場合）は終了
            if filteredImages.isEmpty, result.count > 0 {
                break
            }
        }

        print("📊 URL取得状況:")
        print("   要求数: \(requestedCount)件 → 取得数: \(totalFetched)件")
        print("   許可された拡張子: \(allowedExtensions.joined(separator: ", "))")
        print("   フィルター後: \(result.count)件")

        return Array(result.prefix(requestedCount))
    }
}
