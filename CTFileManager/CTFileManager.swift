import Foundation

public actor CTFileManager: CTFileManagerProtocol {
    private let fileManager = FileManager.default
    private let datasetDirectory: URL

    public init(datasetDirectory: URL? = nil) {
        if let datasetDirectory {
            self.datasetDirectory = datasetDirectory
            return
        }
        
        let currentFileURL = URL(fileURLWithPath: #filePath)
        self.datasetDirectory = currentFileURL
            .deletingLastPathComponent() // CTFileManager
            .deletingLastPathComponent() // root
            .appendingPathComponent("Dataset")
    }

    private var unverifiedDirectory: URL {
        datasetDirectory.appendingPathComponent("Unverified")
    }

    private var verifiedDirectory: URL {
        datasetDirectory.appendingPathComponent("Verified")
    }

    /// 画像データを指定されたラベルのディレクトリに保存
    public func saveImage(_ imageData: Data, fileName: String, label: String) async throws {
        do {
            try fileManager.createDirectory(at: unverifiedDirectory, withIntermediateDirectories: true)
            let labelDirectory = unverifiedDirectory.appendingPathComponent(label)
            try fileManager.createDirectory(at: labelDirectory, withIntermediateDirectories: true)
            let fileURL = labelDirectory.appendingPathComponent(fileName)
            try imageData.write(to: fileURL)
        } catch {
            throw CTFileManagerError.fileOperationFailed(error)
        }
    }

    public func fileExists(fileName: String, label: String, isVerified: Bool) async -> Bool {
        let baseDirectory = isVerified ? verifiedDirectory : unverifiedDirectory
        let labelDirectory = baseDirectory.appendingPathComponent(label)
        let fileURL = labelDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
}
