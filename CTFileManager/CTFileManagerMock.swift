import Foundation

public final class CTFileManagerMock: CTFileManagerProtocol {
    public var saveImageError: Error?
    public var fileExistsResult: Bool = false
    
    public init() {}
    
    public func saveImage(_ imageData: Data, fileName: String, label: String) async throws {
        if let error = saveImageError {
            throw error
        }
    }
    
    public func fileExists(fileName: String, label: String) -> Bool {
        return fileExistsResult
    }
} 