import Foundation
import ICTShared

public class CatAPIClient {
    private let baseURL = "https://api.thecatapi.com/v1/images/search"

    public init() {}

    public func fetchCatImageURLs(count: Int = 10) async throws -> [URL] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(count)),
            URLQueryItem(name: "mime_types", value: "jpg"),
        ]

        let request = URLRequest(url: components.url!)
        let (data, _) = try await URLSession.shared.data(for: request)
        let images = try JSONDecoder().decode([CatImage].self, from: data)
        return images.map { URL(string: $0.url)! }
    }
}
