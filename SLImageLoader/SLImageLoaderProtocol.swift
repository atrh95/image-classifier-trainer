import Foundation

public protocol SLImageLoaderProtocol {
    func downloadImage(from url: URL) async throws -> Data
    func loadLocalImage(from url: URL) async throws -> Data
}
