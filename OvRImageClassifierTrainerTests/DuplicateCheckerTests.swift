import XCTest
@testable import DuplicateChecker
@testable import CTFileManager

final class DuplicateCheckerTests: XCTestCase {
    var sut: DuplicateChecker!
    var mockFileManager: MockCTFileManager!
    
    override func setUp() async throws {
        try await super.setUp()
        mockFileManager = MockCTFileManager()
        sut = DuplicateChecker(fileManager: mockFileManager)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockFileManager = nil
        try await super.tearDown()
    }
    
    func test_initializeHashes_shouldLoadHashesFromBothDirectories() async throws {
        let verifiedData = "verified".data(using: .utf8)!
        let unverifiedData = "unverified".data(using: .utf8)!
        mockFileManager.mockImageData = [
            ("verified.jpg", verifiedData, true),
            ("unverified.jpg", unverifiedData, false)
        ]
        
        try await sut.initializeHashes()
        
        let result1 = try await sut.checkDuplicate(
            imageData: verifiedData,
            fileName: "test1.jpg",
            label: "test"
        )
        let result2 = try await sut.checkDuplicate(
            imageData: unverifiedData,
            fileName: "test2.jpg",
            label: "test"
        )
        
        XCTAssertFalse(result1)
        XCTAssertFalse(result2)
    }
    
    func test_checkDuplicate_shouldReturnFalse_whenFileNameExists() async throws {
        mockFileManager.mockFileExists = true
        
        let result = try await sut.checkDuplicate(
            imageData: "test".data(using: .utf8)!,
            fileName: "test.jpg",
            label: "test"
        )
        
        XCTAssertFalse(result)
    }
    
    func test_checkDuplicate_shouldReturnFalse_whenHashExists() async throws {
        let imageData = "test".data(using: .utf8)!
        try await sut.initializeHashes()
        await sut.addHash(imageData: imageData)
        
        let result = try await sut.checkDuplicate(
            imageData: imageData,
            fileName: "test.jpg",
            label: "test"
        )
        
        XCTAssertFalse(result)
    }
    
    func test_checkDuplicate_shouldReturnTrue_whenNoDuplicate() async throws {
        mockFileManager.mockFileExists = false
        try await sut.initializeHashes()
        
        let result = try await sut.checkDuplicate(
            imageData: "test".data(using: .utf8)!,
            fileName: "test.jpg",
            label: "test"
        )
        
        XCTAssertTrue(result)
    }
    
    func test_addHash_shouldAddHashToSet() async throws {
        let imageData = "test".data(using: .utf8)!
        try await sut.initializeHashes()
        
        await sut.addHash(imageData: imageData)
        
        let result = try await sut.checkDuplicate(
            imageData: imageData,
            fileName: "test.jpg",
            label: "test"
        )
        XCTAssertFalse(result)
    }
} 