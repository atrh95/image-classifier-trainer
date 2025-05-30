import Foundation

public enum CTFileManagerError: Error {
    case directoryEnumerationFailed
    case fileNotFound
    case saveFailed
    case invalidData
}
