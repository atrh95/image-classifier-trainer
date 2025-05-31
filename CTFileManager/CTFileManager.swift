import Foundation
import CryptoKit

public actor CTFileManager: CTFileManagerProtocol {
    private let fileManager = FileManager.default
    private let datasetDirectory: URL
    private var imageHashes: [String: String] = [:] // ハッシュ値とファイル名のマッピング

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

    /// 画像データのハッシュ値を計算
    private func calculateImageHash(_ imageData: Data) -> String {
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 画像データを指定されたラベルのディレクトリに保存
    public func saveImage(_ imageData: Data, fileName: String, label: String) async throws {
        do {
            // 画像のハッシュ値を計算
            let imageHash = calculateImageHash(imageData)
            
            // 同じハッシュ値を持つ画像が既に存在するかチェック
            if let existingFileName = imageHashes[imageHash] {
                print("   ⚠️ 内容が重複しているため保存をスキップ: \(fileName) (既存ファイル: \(existingFileName))")
                return
            }

            try fileManager.createDirectory(at: unverifiedDirectory, withIntermediateDirectories: true)
            let labelDirectory = unverifiedDirectory.appendingPathComponent(label)
            try fileManager.createDirectory(at: labelDirectory, withIntermediateDirectories: true)
            let fileURL = labelDirectory.appendingPathComponent(fileName)
            try imageData.write(to: fileURL)
            
            // ハッシュ値を保存
            imageHashes[imageHash] = fileName
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

    /// 指定されたディレクトリ内の.mlmodelcファイルを取得
    public func getModelFiles(in directory: URL) async throws -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "mlmodelc" }
        } catch {
            throw CTFileManagerError.fileOperationFailed(error)
        }
    }
}
