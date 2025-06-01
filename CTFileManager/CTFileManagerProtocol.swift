import Foundation

public protocol CTFileManagerProtocol {
    init(datasetDirectory: URL?)
    func saveImage(_ imageData: Data, fileName: String, label: String) async throws
    func fileExists(fileName: String, label: String, isVerified: Bool) async -> Bool
    func getModelFiles(in directory: URL) async throws -> [URL]
    func getAllImageFiles(in directory: String) async throws -> [String]
}
