import SLFileManager
import XCTest

final class SLFileManagerTests: XCTestCase {
    var fileManager: SLFileManager!

    private var tempDirectory: URL {
        let testDirectory = Bundle(for: type(of: self)).bundleURL
            .appendingPathComponent("SLFileManagerTests_Temp")
        return testDirectory
    }

    override func setUp() async throws {
        try await super.setUp()
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileManager = SLFileManager(overrideDatasetDirectory: tempDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        fileManager = nil
        try await super.tearDown()
    }

    /// プロジェクトの想定されたDatasetディレクトリが正しく設定されているかを確認
    func testInitializationWithProjectDatasetDirectory() async throws {
        // SLFileManagerのデフォルトのdatasetDirectoryを直接取得
        let expectedDatasetDirectory = SLFileManager().datasetDirectory

        let fileManager = SLFileManager(overrideDatasetDirectory: nil)
        let actualDirectory = fileManager.datasetDirectory

        XCTAssertEqual(actualDirectory, expectedDatasetDirectory, "想定されたDatasetディレクトリが正しく設定されていません")
    }

    /// 画像データを指定されたラベルのディレクトリに正しく保存できることを確認
    func testSaveImageToUnverifiedDirectory() async throws {
        let imageData = Data("test image data".utf8)
        let fileName = "test.jpg"
        let label = "testLabel"

        try await fileManager.saveImage(imageData, fileName: fileName, label: label)

        let existsUnverified = await fileManager.fileExists(fileName: fileName, label: label, isVerified: false)
        let existsVerified = await fileManager.fileExists(fileName: fileName, label: label, isVerified: true)
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
        let imageData = Data("test image data".utf8)
        let fileName = "test2.jpg"
        let label = "testLabel2"

        let existsBeforeUnverified = await fileManager.fileExists(fileName: fileName, label: label, isVerified: false)
        let existsBeforeVerified = await fileManager.fileExists(fileName: fileName, label: label, isVerified: true)
        XCTAssertFalse(existsBeforeUnverified)
        XCTAssertFalse(existsBeforeVerified)

        try await fileManager.saveImage(imageData, fileName: fileName, label: label)

        let existsAfterUnverified = await fileManager.fileExists(fileName: fileName, label: label, isVerified: false)
        let existsAfterVerified = await fileManager.fileExists(fileName: fileName, label: label, isVerified: true)
        XCTAssertTrue(existsAfterUnverified)
        XCTAssertFalse(existsAfterVerified)
    }

    /// ファイル操作のエラーが適切に処理されることを確認
    func testSaveImageFailsWithInsufficientPermissions() async throws {
        let imageData = Data("test".utf8)
        let fileName = "test.jpg"
        let label = "testLabel"

        // ディレクトリを読み取り専用に設定
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: tempDirectory.path)

        do {
            try await fileManager.saveImage(imageData, fileName: fileName, label: label)
            XCTFail("Expected saveImage to throw an error due to insufficient permissions")
        } catch {
            XCTAssertTrue(error is SLFileManagerError)
        }

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempDirectory.path)
    }
}
