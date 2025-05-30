import Foundation

public protocol CTImageLoaderProtocol {
    func downloadAndSaveImage(from url: URL, label: String) async throws
} 