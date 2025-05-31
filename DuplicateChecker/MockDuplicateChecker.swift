import Foundation

/// DuplicateCheckerProtocolのモック実装
final class MockDuplicateChecker: DuplicateCheckerProtocol {
    private var imageHashes: Set<String> = []
    private var shouldReturnDuplicate: Bool = false
    
    /// 重複チェックの結果を設定する
    /// - Parameter shouldReturnDuplicate: 重複がある場合はtrue、ない場合はfalse
    func setShouldReturnDuplicate(_ shouldReturnDuplicate: Bool) {
        self.shouldReturnDuplicate = shouldReturnDuplicate
    }
    
    func initializeHashes() async throws {
        imageHashes.removeAll()
    }
    
    func checkDuplicate(imageData: Data, fileName: String, label: String) async throws -> Bool {
        return !shouldReturnDuplicate
    }
    
    func addHash(imageData: Data) async {
        let hash = String(imageData.hashValue)
        imageHashes.insert(hash)
    }
} 