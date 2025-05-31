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

    /// 指定されたディレクトリ内のすべての画像ファイルのパスを取得
    public func getAllImageFiles(in directory: String) async throws -> [String] {
        do {
            let directoryURL = datasetDirectory.appendingPathComponent(directory)
            let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            var imageFiles: [String] = []
            while let fileURL = enumerator?.nextObject() as? URL {
                let fileExtension = fileURL.pathExtension.lowercased()
                if ["jpg", "jpeg", "png"].contains(fileExtension) {
                    imageFiles.append(fileURL.path)
                }
            }
            return imageFiles
        } catch {
            throw CTFileManagerError.fileOperationFailed(error)
        }
    }
}
