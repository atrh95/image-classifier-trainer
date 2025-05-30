import Foundation

public protocol CatAPIClientProtocol {
    func fetchImageURLs(requestedCount: Int, batchSize: Int) async throws -> [CatImageURLModel]
}
