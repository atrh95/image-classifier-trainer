import Foundation

final actor DuplicateChecker: DuplicateCheckerProtocol {
    private var imageHashes: Set<String> = []
    private let fileManager: CTFileManagerProtocol
    
    init(fileManager: CTFileManagerProtocol) {
        self.fileManager = fileManager
    }
    
    func initializeHashes() async throws {
        // 既存のハッシュをクリア
        imageHashes.removeAll()
        
        // 確認済みと未確認の両方のデータセットからハッシュを読み込む
        let verifiedHashes = try await loadHashesFromDirectory(isVerified: true)
        let unverifiedHashes = try await loadHashesFromDirectory(isVerified: false)
        
        // すべてのハッシュを結合
        imageHashes = verifiedHashes.union(unverifiedHashes)
    }
    
    private func loadHashesFromDirectory(isVerified: Bool) async throws -> Set<String> {
        var hashes = Set<String>()
        let directory = isVerified ? "Dataset/Verified" : "Dataset/Unverified"
        
        // ディレクトリとそのサブディレクトリ内のすべての画像ファイルを取得
        let files = try await fileManager.getAllImageFiles(in: directory)
        
        for file in files {
            if let imageData = try? await fileManager.loadImageData(fileName: file, label: "", isVerified: isVerified) {
                let hash = String(imageData.hashValue)
                hashes.insert(hash)
            }
        }
        
        return hashes
    }
    
    /// 画像が重複しているかチェック、重複がない場合はtrue、重複がある場合はfalseを返す
    func checkDuplicate(imageData: Data, fileName: String, label: String) async throws -> Bool {
        // まず、ファイル名がどちらかのデータセットに存在するかチェック
        let existsInVerified = await fileManager.fileExists(
            fileName: fileName,
            label: label,
            isVerified: true
        )
        let existsInUnverified = await fileManager.fileExists(
            fileName: fileName,
            label: label,
            isVerified: false
        )
        
        if existsInVerified || existsInUnverified {
            return false
        }
        
        // 次に、画像コンテンツのハッシュが存在するかチェック
        let hash = String(imageData.hashValue)
        if imageHashes.contains(hash) {
            return false
        }
        
        return true
    }
    
    /// 新しい画像のハッシュを追加する
    /// - Parameter imageData: 追加する画像データ
    func addHash(imageData: Data) async {
        let hash = String(imageData.hashValue)
        imageHashes.insert(hash)
    }
} 