import Foundation

public struct DetectedFeature {
    public let label: String
    public let confidence: Float
    public let imageData: Data

    public init(label: String, confidence: Float, imageData: Data) {
        self.label = label
        self.confidence = confidence
        self.imageData = imageData
    }
}
