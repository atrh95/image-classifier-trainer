import Foundation

public final class CatAPIClientMock: CatAPIClientProtocol {
    public var fetchImageURLsResult: [CatImageURLModel] = []
    public var fetchImageURLsError: Error?

    public init() {}

    public func fetchImageURLs(requestedCount: Int, batchSize _: Int) async throws -> [CatImageURLModel] {
        if let error = fetchImageURLsError {
            throw error
        }
        return Array(fetchImageURLsResult.prefix(requestedCount))
    }
}
