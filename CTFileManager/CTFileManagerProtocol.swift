import Foundation

public protocol CTFileManagerProtocol {
    init(datasetDirectory: URL?)
    func saveImage(_ imageData: Data, fileName: String, label: String) async throws
    func fileExists(fileName: String, label: String, isVerified: Bool) async -> Bool
    func getModelFiles(in directory: URL) async throws -> [URL]
    /// 指定されたディレクトリ内のすべての画像ファイルのパスを取得
    func getAllImageFiles(in directory: String) async throws -> [String]
}
