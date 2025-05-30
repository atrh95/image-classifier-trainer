import Foundation

public enum ImageLoaderError: Error {
    case downloadFailed
    case invalidData
    case sampleImageNotFound
}
