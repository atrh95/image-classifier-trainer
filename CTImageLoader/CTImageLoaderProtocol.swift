import Foundation

public protocol CTImageLoaderProtocol {
    func downloadImage(from url: URL) async throws -> Data
    func loadLocalImage(from url: URL) async throws -> Data
}
