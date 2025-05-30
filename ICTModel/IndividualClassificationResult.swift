import Foundation

public struct IndividualClassificationResult {
    public let label: String
    public let confidence: Float

    public init(label: String, confidence: Float) {
        self.label = label
        self.confidence = confidence
    }
}
