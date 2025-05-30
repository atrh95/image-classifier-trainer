import Foundation

public enum ClassificationError: Error {
    case resourceBundleNotFound
    case modelNotFound
    case modelLoadingFailed
    case classificationFailed
}
