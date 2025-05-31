import Foundation

public final class MockCTFileManager: CTFileManagerProtocol {
    public var saveImageError: Error?
    /// fileExistsメソッドの戻り値を制御するためのプロパティ
    public var fileExistsResult: Bool = false
    /// 指定されたディレクトリ内の画像ファイルパスのリストを設定するためのプロパティ
    public var mockImageFiles: [String: [String]] = [:]
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
    
    /// 指定されたディレクトリ内のすべての画像ファイルのパスを取得
    public func getAllImageFiles(in directory: String) async throws -> [String] {
        return mockImageFiles[directory] ?? []
    }
}
