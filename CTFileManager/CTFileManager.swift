import Foundation

public actor CTFileManager: CTFileManagerProtocol {
    private let fileManager = FileManager.default

    private var datasetDirectory: URL {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent() // CTFileManager
            .deletingLastPathComponent() // root
            .appendingPathComponent("Dataset")
    }
    
    private var unverifiedDirectory: URL {
        datasetDirectory.appendingPathComponent("Unverified")
    }

    public init() {
        try? fileManager.createDirectory(at: unverifiedDirectory, withIntermediateDirectories: true)
    }

    /// 画像データを指定されたラベルのディレクトリに保存
    public func saveImage(_ imageData: Data, fileName: String, label: String) async throws {
        let labelDirectory = unverifiedDirectory.appendingPathComponent(label)
        try fileManager.createDirectory(at: labelDirectory, withIntermediateDirectories: true)
        let fileURL = labelDirectory.appendingPathComponent(fileName)
        try imageData.write(to: fileURL)
    }

    public func fileExists(fileName: String, label: String) -> Bool {
        let labelDirectory = unverifiedDirectory.appendingPathComponent(label)
        let fileURL = labelDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
}
