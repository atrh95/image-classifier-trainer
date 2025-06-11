import SLClassifier
import SLFileManager
import SLImageLoader
import XCTest

final class SLClassifierTests: XCTestCase {
    private var classifier: SLClassifier!
    private var mockFileManager: MockSLFileManager!
    private var mockImageLoader: MockSLImageLoader!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockFileManager = MockSLFileManager()
        mockImageLoader = MockSLImageLoader()
    }

    override func tearDown() {
        classifier = nil
        mockFileManager = nil
        mockImageLoader = nil
        super.tearDown()
    }

    /// 画像の分類処理がエラーなく完了する
    func testGetThresholdedFeaturesCompletes() async throws {
        classifier = try await SLClassifier(
            fileManager: mockFileManager,
            imageLoader: mockImageLoader
        )
        
        let imageData = try await mockImageLoader.downloadImage(from: mockImageLoader.testImageURL)

        _ = try await classifier.getThresholdedFeatures(
            data: imageData
        )
    }
}
