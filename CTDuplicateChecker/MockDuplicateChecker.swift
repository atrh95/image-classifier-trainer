import Foundation

public final class MockDuplicateChecker: DuplicateCheckerProtocol {
    private var imageHashes: Set<String> = []
    private var shouldReturnDuplicate: Bool = false
    
    public init() {}
    
    /// 重複チェックの結果を設定する
    /// - Parameter shouldReturnDuplicate: 重複がある場合はtrue、ない場合はfalse
    public func setShouldReturnDuplicate(_ shouldReturnDuplicate: Bool) {
        self.shouldReturnDuplicate = shouldReturnDuplicate
    }
    
    public func initializeHashes() async throws {
        imageHashes.removeAll()
    }
    
    public func checkDuplicate(imageData: Data, fileName: String, label: String) async throws -> Bool {
        return !shouldReturnDuplicate
    }
    
    public func addHash(imageData: Data) async {
        let hash = String(imageData.hashValue)
        imageHashes.insert(hash)
    }
} 
