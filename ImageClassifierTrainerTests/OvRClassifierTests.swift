import CatAPIClient
import CTFileManager
import CTImageLoader
import OvRClassification
import XCTest

final class OvRClassifierTests: XCTestCase {
    private var classifier: OvRClassifier!
    private var fileManagerMock: MockCTFileManager!
    private var imageLoaderMock: MockCTImageLoader!

    override func setUp() async throws {
        try await super.setUp()
        fileManagerMock = MockCTFileManager()
        imageLoaderMock = MockCTImageLoader()
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
    func testSingleClassifyImageFromURLCompletes() async throws {
        let threshold: Float = 0.5

        _ = try await classifier.classifyImageFromURL(
            from: imageLoaderMock.testImageURL,
            threshold: threshold
        )
    }
}
