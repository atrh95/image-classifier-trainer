import XCTest
import CTDuplicateChecker
import CTFileManager
import CTImageLoader

final class CTDuplicateCheckerTests: XCTestCase {
    var sut: DuplicateChecker!
    var mockFileManager: MockCTFileManager!
    var mockImageLoader: MockCTImageLoader!
    var sampleImageData: Data!
    
    override func setUp() async throws {
        try await super.setUp()
        mockFileManager = MockCTFileManager()
        mockImageLoader = MockCTImageLoader()
        sut = DuplicateChecker(fileManager: mockFileManager, imageLoader: mockImageLoader)
        
        // モックのdownloadImageメソッドからサンプル画像データを取得
        sampleImageData = try await mockImageLoader.downloadImage(from: mockImageLoader.testImageURL)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockFileManager = nil
        mockImageLoader = nil
        sampleImageData = nil
        try await super.tearDown()
    }
    
    /// 確認済みと未確認の両方のディレクトリから画像ハッシュを読み込み、重複チェックが正しく機能することを確認
    func testInitializeHashesLoadsHashesFromBothVerifiedAndUnverifiedDirectories() async throws {
        // モックの画像ファイルパスを設定
        let verifiedFile = "/path/to/verified.jpg"
        let unverifiedFile = "/path/to/unverified.jpg"
        mockFileManager.mockImageFiles = [
            "Dataset/Verified": [verifiedFile],
            "Dataset/Unverified": [unverifiedFile]
        ]
        
        // モックの画像データを設定
        mockImageLoader.mockLocalImageData = [
            URL(fileURLWithPath: verifiedFile): sampleImageData,
            URL(fileURLWithPath: unverifiedFile): sampleImageData
        ]
        
        try await sut.initializeHashes()
        
        let result1 = try await sut.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test1.jpg",
            label: "test"
        )
        let result2 = try await sut.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test2.jpg",
            label: "test"
        )
        
        XCTAssertFalse(result1)
        XCTAssertFalse(result2)
    }
    
    /// 同じファイル名が存在する場合、重複と判定されることを確認
    func testCheckDuplicateReturnsFalseWhenFileNameExistsInVerifiedDirectory() async throws {
        mockFileManager.fileExistsResult = true
        
        let result = try await sut.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test.jpg",
            label: "test"
        )
        
        XCTAssertFalse(result)
    }
    
    /// 同じ画像ハッシュがメモリ上に存在する場合、重複と判定されることを確認
    func testCheckDuplicateReturnsFalseWhenImageHashExistsInMemory() async throws {
        try await sut.initializeHashes()
        await sut.addHash(imageData: sampleImageData)
        
        let result = try await sut.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test.jpg",
            label: "test"
        )
        
        XCTAssertFalse(result)
    }
    
    /// ファイル名とハッシュの両方が重複していない場合、重複なしと判定されることを確認
    func testCheckDuplicateReturnsTrueWhenNoDuplicateFound() async throws {
        mockFileManager.fileExistsResult = false
        try await sut.initializeHashes()
        
        let result = try await sut.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test.jpg",
            label: "test"
        )
        
        XCTAssertTrue(result)
    }
    
    /// 新しい画像のハッシュがメモリ上に正しく保存され、重複チェックに使用できることを確認
    func testAddHashStoresImageHashInMemory() async throws {
        try await sut.initializeHashes()
        
        await sut.addHash(imageData: sampleImageData)
        
        let result = try await sut.checkDuplicate(
            imageData: sampleImageData,
            fileName: "test.jpg",
            label: "test"
        )
        XCTAssertFalse(result)
    }
} 
