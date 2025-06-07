import Foundation

public final class MockCatAPIClient: CatAPIClientProtocol {
    public var fetchImageURLsError: Error?
    // MockSLImageLoaderがサンプル画像を使用するため、これらのURLは実際には使用されない
    private let dummyData = [
        (id: "cat1", url: "https://example.com/cat1.jpg", width: 800, height: 600),
        (id: "cat2", url: "https://example.com/cat2.jpg", width: 1024, height: 768),
        (id: "cat3", url: "https://example.com/cat3.jpg", width: 640, height: 480),
    ]

    public init() {}

    public func fetchImageURLs(requestedCount: Int, batchSize _: Int) async throws -> [CatImageURLModel] {
        if let error = fetchImageURLsError {
            throw error
        }
        return Array(dummyData.prefix(requestedCount).map { data in
            CatImageURLModel(id: data.id, url: data.url, width: data.width, height: data.height)
        })
    }
}
