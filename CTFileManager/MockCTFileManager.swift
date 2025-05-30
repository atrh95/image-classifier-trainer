import Foundation

public final class MockCTFileManager: CTFileManagerProtocol {
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

    /// 指定されたディレクトリ内の.mlmodelcファイルを取得
    public func getModelFiles(in directory: URL) async throws -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "mlmodelc" }
        } catch {
            throw CTFileManagerError.fileOperationFailed(error)
        }
    }
}
