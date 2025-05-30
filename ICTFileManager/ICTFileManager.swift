import Foundation

actor ICTFileManager {
    private let enableLogging: Bool
    private let imageLoader: ICTImageLoader
    private var outputDirPath: String {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent() // ICTFileManager
            .deletingLastPathComponent() // root
            .appendingPathComponent("Dataset")
            .path
    }

    init(enableLogging: Bool = true) {
        self.enableLogging = enableLogging
        imageLoader = ICTImageLoader(enableLogging: enableLogging)
    }

    /// 指定されたラベルのディレクトリが存在することを確認し、必要に応じて作成
    func ensureDirectoryExists(for label: String) async throws {
        let directoryURL = URL(fileURLWithPath: outputDirPath).appendingPathComponent(label)
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            if enableLogging {
                print("[ICTFileManager] [Info] 新しいディレクトリを作成: \(label)")
            }
        }
    }

    /// 画像データを指定されたラベルのディレクトリに保存
    func saveImage(_ imageData: Data, fileName: String, label: String) async throws {
        try await ensureDirectoryExists(for: label)

        let directory = "\(outputDirPath)/\(label)"
        let fileURL = URL(fileURLWithPath: directory).appendingPathComponent(fileName)

        try imageData.write(to: fileURL)
        if enableLogging {
            print("[ICTFileManager] [Info] 画像を保存: \(fileURL.path)")
        }
    }

    /// URLから画像をダウンロードして保存
    func downloadAndSaveImage(from url: URL, label: String) async throws {
        let data = try await imageLoader.downloadImage(from: url)
        try await saveImage(data, fileName: url.lastPathComponent, label: label)
    }

    /// 指定されたディレクトリ内の.mlmodelcファイルを検索
    func findModelFiles(in directory: String) async throws -> [URL] {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directory)
        let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey]

        if enableLogging {
            print("[ICTFileManager] [Debug] 検索ディレクトリ: \(directoryURL.path)")
        }

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: .skipsHiddenFiles
        ) else {
            if enableLogging {
                print("[ICTFileManager] [Error] ディレクトリの列挙に失敗: \(directoryURL.path)")
            }
            throw FileError.directoryEnumerationFailed
        }

        var modelFileURLs: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "mlmodelc" {
            modelFileURLs.append(fileURL)
            if enableLogging {
                print("[ICTFileManager] [Debug] モデルファイルを検出: \(fileURL.lastPathComponent)")
            }
        }

        if enableLogging {
            print(
                "[ICTFileManager] [Debug] 検出されたモデル: \(modelFileURLs.map(\.lastPathComponent).joined(separator: ", "))"
            )
        }

        return modelFileURLs
    }
}

// MARK: - Supporting Types

enum FileError: Error {
    case directoryEnumerationFailed
    case fileNotFound
    case saveFailed
    case invalidData
}
