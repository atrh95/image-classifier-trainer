import Foundation

public actor CTFileManager {
    private let fileManager = FileManager.default

    private var datasetDirectory: URL {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent() // CTFileManager
            .deletingLastPathComponent() // root
            .appendingPathComponent("Dataset")
    }
    
    private var verifiedDirectory: URL {
        datasetDirectory.appendingPathComponent("Verified")
    }
    
    private var unverifiedDirectory: URL {
        datasetDirectory.appendingPathComponent("Unverified")
    }

    public init() {
        try? fileManager.createDirectory(at: verifiedDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: unverifiedDirectory, withIntermediateDirectories: true)
    }

    /// 画像データを指定されたラベルのディレクトリに保存
    public func saveImage(_ imageData: Data, fileName: String, label: String, isVerified: Bool) async throws {
        let baseDirectory = isVerified ? verifiedDirectory : unverifiedDirectory
        let labelDirectory = baseDirectory.appendingPathComponent(label)
        try fileManager.createDirectory(at: labelDirectory, withIntermediateDirectories: true)
        let fileURL = labelDirectory.appendingPathComponent(fileName)
        try imageData.write(to: fileURL)
    }

    public func fileExists(fileName: String, label: String, isVerified: Bool) -> Bool {
        let baseDirectory = isVerified ? verifiedDirectory : unverifiedDirectory
        let labelDirectory = baseDirectory.appendingPathComponent(label)
        let fileURL = labelDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// 未確認の画像を確認済みに移動
    public func moveToVerified(fileName: String, label: String) async throws {
        let sourceURL = unverifiedDirectory.appendingPathComponent(label).appendingPathComponent(fileName)
        let destinationURL = verifiedDirectory.appendingPathComponent(label).appendingPathComponent(fileName)
        
        // 移動先のディレクトリが存在しない場合は作成
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // ファイルを移動
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }
}
