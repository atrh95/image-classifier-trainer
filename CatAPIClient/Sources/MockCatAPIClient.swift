import Foundation

public final class MockCatAPIClient: CatAPIClientProtocol {
    public var fetchImageURLsError: Error?
    
    private let dummyData = CatImageURLModel(
        id: "test_cat",
        url: "https://example.com/test_cat.jpg",
        width: 800,
        height: 600
    )

    public init() {}

    public func fetchImageURLs(requestedCount: Int, batchSize _: Int) async throws -> [CatImageURLModel] {
        if let error = fetchImageURLsError {
            throw error
        }
        return Array(repeating: dummyData, count: requestedCount)
    }
}
