import Foundation

public protocol CTFileManagerProtocol {
    func saveImage(_ imageData: Data, fileName: String, label: String) async throws
    func fileExists(fileName: String, label: String, isVerified: Bool) async -> Bool
}
