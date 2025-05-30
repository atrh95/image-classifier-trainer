import CTFileManager
import XCTest

final class CTFileManagerTests: XCTestCase {
    var sut: CTFileManager!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        sut = CTFileManager(datasetDirectory: tempDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        sut = nil
        try await super.tearDown()
    }

    /// 画像データを指定されたラベルのディレクトリに正しく保存できることを確認
    func testSaveImageToUnverifiedDirectory() async throws {
        let imageData = "test image data".data(using: .utf8)!
        let fileName = "test.jpg"
        let label = "testLabel"

        try await sut.saveImage(imageData, fileName: fileName, label: label)

        let existsUnverified = await sut.fileExists(fileName: fileName, label: label, isVerified: false)
        let existsVerified = await sut.fileExists(fileName: fileName, label: label, isVerified: true)
        XCTAssertTrue(existsUnverified)
        XCTAssertFalse(existsVerified)

        let fileURL = tempDirectory
            .appendingPathComponent("Unverified")
            .appendingPathComponent(label)
            .appendingPathComponent(fileName)
        let savedData = try Data(contentsOf: fileURL)
        XCTAssertEqual(savedData, imageData)
    }

    /// ファイルの存在確認が正しく動作することを確認
    func testFileExistsInUnverifiedAndVerifiedDirectories() async throws {
        let imageData = "test image data".data(using: .utf8)!
        let fileName = "test2.jpg"
        let label = "testLabel2"

        let existsBeforeUnverified = await sut.fileExists(fileName: fileName, label: label, isVerified: false)
        let existsBeforeVerified = await sut.fileExists(fileName: fileName, label: label, isVerified: true)
        XCTAssertFalse(existsBeforeUnverified)
        XCTAssertFalse(existsBeforeVerified)

        try await sut.saveImage(imageData, fileName: fileName, label: label)

        let existsAfterUnverified = await sut.fileExists(fileName: fileName, label: label, isVerified: false)
        let existsAfterVerified = await sut.fileExists(fileName: fileName, label: label, isVerified: true)
        XCTAssertTrue(existsAfterUnverified)
        XCTAssertFalse(existsAfterVerified)
    }

    /// ファイル操作のエラーが適切に処理されることを確認
    func testSaveImageFailsWithInsufficientPermissions() async throws {
        let imageData = "test".data(using: .utf8)!
        let fileName = "test.jpg"
        let label = "testLabel"

        // ディレクトリを読み取り専用に設定
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: tempDirectory.path)

        do {
            try await sut.saveImage(imageData, fileName: fileName, label: label)
            XCTFail()
        } catch {
            XCTAssertTrue(error is CTFileManagerError)
        }

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempDirectory.path)
    }
}
