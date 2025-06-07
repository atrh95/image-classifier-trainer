import Foundation

public enum SLImageLoaderError: Error {
    case downloadFailed
    case sampleImageNotFound
    case fileNotFound
    case unsupportedFileType
}
