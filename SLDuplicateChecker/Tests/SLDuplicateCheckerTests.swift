import SLDuplicateChecker
import SLFileManager
import SLImageLoader
import XCTest

final class SLDuplicateCheckerTests: XCTestCase {
    var duplicateChecker: DuplicateChecker!
    var mockFileManager: MockSLFileManager!
    var mockImageLoader: MockSLImageLoader!
    var sampleImageData: Data!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockFileManager = MockSLFileManager()
        mockImageLoader = MockSLImageLoader()
        duplicateChecker = DuplicateChecker(fileManager: mockFileManager, imageLoader: mockImageLoader)
    }

    override func tearDownWithError() throws {
        duplicateChecker = nil
        mockFileManager = nil
        mockImageLoader = nil
        sampleImageData = nil
        try super.tearDownWithError()
    }

    /// 確認済みと未確認の両方のディレクトリから画像ハッシュを読み込み、重複チェックが正しく機能することを確認
    func testInitializeHashesLoadsHashesFromBothVerifiedAndUnverifiedDirectories() async throws {
        // モックのdownloadImageメソッドからサンプル画像データを取得
        sampleImageData = try await mockImageLoader.downloadImage(from: mockImageLoader.testImageURL)
        
        // モックの画像ファイルパスを設定
        let verifiedFile = "/path/to/verified.jpg"
        let unverifiedFile = "/path/to/unverified.jpg"
        mockFileManager.mockImageFiles = [
            "Verified": [verifiedFile],
            "Unverified": [unverifiedFile],
        ]

        // モックの画像データを設定
        mockImageLoader.mockLocalImageData = [
            URL(fileURLWithPath: verifiedFile): sampleImageData,
            URL(fileURLWithPath: unverifiedFile): sampleImageData,
        ]

        try await duplicateChecker.initializeHashes()

        let result1 = try await duplicateChecker.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test1.jpg",
            label: "test"
        )
        let result2 = try await duplicateChecker.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test2.jpg",
            label: "test"
        )

        XCTAssertFalse(result1)
        XCTAssertFalse(result2)
    }

    /// 同じファイル名が存在する場合、重複と判定されることを確認
    func testCheckDuplicateReturnsFalseWhenFileNameExistsInVerifiedDirectory() async throws {
        sampleImageData = try await mockImageLoader.downloadImage(from: mockImageLoader.testImageURL)
        mockFileManager.fileExistsResult = true

        let result = try await duplicateChecker.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test.jpg",
            label: "test"
        )

        XCTAssertFalse(result)
    }

    /// 同じ画像ハッシュがメモリ上に存在する場合、重複と判定されることを確認
    func testCheckDuplicateReturnsFalseWhenImageHashExistsInMemory() async throws {
        sampleImageData = try await mockImageLoader.downloadImage(from: mockImageLoader.testImageURL)
        try await duplicateChecker.initializeHashes()
        await duplicateChecker.addHash(imageData: sampleImageData)

        let result = try await duplicateChecker.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test.jpg",
            label: "test"
        )

        XCTAssertFalse(result)
    }

    /// ファイル名とハッシュの両方が重複していない場合、重複なしと判定されることを確認
    func testCheckDuplicateReturnsTrueWhenNoDuplicateFound() async throws {
        sampleImageData = try await mockImageLoader.downloadImage(from: mockImageLoader.testImageURL)
        mockFileManager.fileExistsResult = false
        try await duplicateChecker.initializeHashes()

        let result = try await duplicateChecker.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test.jpg",
            label: "test"
        )

        XCTAssertTrue(result)
    }

    /// 新しい画像のハッシュがメモリ上に正しく保存され、重複チェックに使用できることを確認
    func testAddHashStoresImageHashInMemory() async throws {
        sampleImageData = try await mockImageLoader.downloadImage(from: mockImageLoader.testImageURL)
        try await duplicateChecker.initializeHashes()

        await duplicateChecker.addHash(imageData: sampleImageData)

        let result = try await duplicateChecker.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test.jpg",
            label: "test"
        )
        XCTAssertFalse(result)
    }
}
