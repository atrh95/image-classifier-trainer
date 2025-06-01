import Foundation

public actor SLFileManager: SLFileManagerProtocol {
    private let fileManager = FileManager.default
    private let datasetDirectory: URL

    public init(datasetDirectory: URL? = nil) {
        if let datasetDirectory {
            self.datasetDirectory = datasetDirectory
        } else {
            let currentFileURL = URL(fileURLWithPath: #file)
            self.datasetDirectory = currentFileURL
                .deletingLastPathComponent() // SLFileManager
                .deletingLastPathComponent() // SLFileManager
                .deletingLastPathComponent() // Sources
                .deletingLastPathComponent() // Project root
        }
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
            throw SLFileManagerError.fileOperationFailed(error)
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
            throw SLFileManagerError.fileOperationFailed(error)
        }
    }

    /// 指定されたディレクトリ内のすべての画像ファイルのパスを取得
    public func getAllImageFiles(in directory: String) async throws -> [String] {
        do {
            // directoryには既にDataset/VerifiedやDataset/Unverifiedが含まれているので、
            // datasetDirectoryの親ディレクトリから相対パスを構築
            let directoryURL = datasetDirectory
                .deletingLastPathComponent() // Dataset
                .appendingPathComponent(directory)

            // 再帰的にサブディレクトリを検索
            guard let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                print("   ❌ ディレクトリの列挙に失敗")
                return []
            }

            var imageFiles: [String] = []

            // 各エントリを処理
            for case let fileURL as URL in enumerator {
                // ファイルの属性を取得
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])

                // 通常ファイルの場合のみ処理
                if resourceValues.isRegularFile == true {
                    let fileExtension = fileURL.pathExtension.lowercased()
                    if ["jpg", "jpeg", "png"].contains(fileExtension) {
                        imageFiles.append(fileURL.path)
                    }
                }
            }

            return imageFiles
        } catch {
            print("   ❌ ディレクトリの検索に失敗: \(error)")
            throw SLFileManagerError.fileOperationFailed(error)
        }
    }
}
