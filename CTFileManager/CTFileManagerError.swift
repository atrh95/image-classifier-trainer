import Foundation

public enum CTFileManagerError: Error {
    case invalidFileName
    case emptyLabel
    case fileOperationFailed(Error)
}
