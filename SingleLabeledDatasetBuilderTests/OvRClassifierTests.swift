import SLFileManager
import SLImageLoader
import OvRClassification
import XCTest

final class OvRClassifierTests: XCTestCase {
    private var classifier: OvRClassifier!
    private var fileManagerMock: MockSLFileManager!
    private var imageLoaderMock: MockSLImageLoader!

    override func setUp() async throws {
        try await super.setUp()
        fileManagerMock = MockSLFileManager()
        imageLoaderMock = MockSLImageLoader()
        classifier = try await OvRClassifier(
            fileManager: fileManagerMock,
            imageLoader: imageLoaderMock
        )
    }

    override func tearDown() {
        classifier = nil
        fileManagerMock = nil
        imageLoaderMock = nil
        super.tearDown()
    }

    /// 画像の分類処理がエラーなく完了する
    func testGetThresholdedFeaturesCompletes() async throws {
        let threshold: Float = 0.5
        let imageData = try await imageLoaderMock.downloadImage(from: imageLoaderMock.testImageURL)

        _ = try await classifier.getThresholdedFeatures(
            data: imageData,
            threshold: threshold
        )
    }
}
