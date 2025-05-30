import Foundation

public final class CTFileManagerMock: CTFileManagerProtocol {
    public var saveImageError: Error?
    public var fileExistsResult: Bool = false
    private let datasetDirectory: URL?

    public init(datasetDirectory: URL? = nil) {
        self.datasetDirectory = datasetDirectory
    }

    public func saveImage(_: Data, fileName _: String, label _: String) async throws {
        if let error = saveImageError {
            throw error
        }
    }

    public func fileExists(fileName _: String, label _: String, isVerified _: Bool) async -> Bool {
        fileExistsResult
    }
}
