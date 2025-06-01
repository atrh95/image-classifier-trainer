import Foundation

public enum SLFileManagerError: Error {
    case invalidFileName
    case emptyLabel
    case fileOperationFailed(Error)
}
