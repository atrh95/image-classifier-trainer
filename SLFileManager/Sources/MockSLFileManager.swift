import Foundation

public final class MockSLFileManager: SLFileManagerProtocol {
    public var saveImageError: Error?
    /// fileExistsメソッドの戻り値を制御するためのプロパティ
    public var fileExistsResult: Bool = false
    /// 指定されたディレクトリ内の画像ファイルパスのリストを設定するためのプロパティ
    public var mockImageFiles: [String: [String]] = [:]
    private var mockSavedImages: [String: Data] = [:]
    private nonisolated let overrideDatasetDirectory: URL?

    public nonisolated var datasetDirectory: URL {
        if let overrideDatasetDirectory {
            return overrideDatasetDirectory
        }
        let currentFileURL = URL(fileURLWithPath: #file)
        return currentFileURL
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // SLFileManager
            .deletingLastPathComponent() // Project root
            .appendingPathComponent("Dataset")
    }

    public init(overrideDatasetDirectory: URL? = nil) {
        self.overrideDatasetDirectory = overrideDatasetDirectory
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
            throw SLFileManagerError.fileOperationFailed(error)
        }
    }

    /// 指定されたディレクトリ内のすべての画像ファイルのパスを取得
    public func getAllImageFiles(isVerified: Bool) async throws -> [String] {
        mockImageFiles[isVerified ? "Verified" : "Unverified"] ?? []
    }
}
