import Foundation

public final class CTImageLoaderMock: CTImageLoaderProtocol {
    public var downloadAndSaveImageError: Error?
    
    public init() {}
    
    public func downloadAndSaveImage(from url: URL, label: String) async throws {
        if let error = downloadAndSaveImageError {
            throw error
        }
    }
} 