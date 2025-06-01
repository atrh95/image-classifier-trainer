import CryptoKit
import CTFileManager
import CTImageLoader
import Foundation

public final actor DuplicateChecker: DuplicateCheckerProtocol {
    private var imageHashes: Set<String> = []
    private let fileManager: CTFileManagerProtocol
    private let imageLoader: CTImageLoaderProtocol

    public init(fileManager: CTFileManagerProtocol, imageLoader: CTImageLoaderProtocol) {
        self.fileManager = fileManager
        self.imageLoader = imageLoader
    }

    public func initializeHashes() async throws {
        print("🔄 重複チェッカーの初期化を開始...")

        // 既存のハッシュをクリア
        imageHashes.removeAll()

        // 確認済みと未確認の両方のデータセットからハッシュを読み込む
        let verifiedHashes = try await loadHashesFromDirectory(isVerified: true)
        let unverifiedHashes = try await loadHashesFromDirectory(isVerified: false)

        // すべてのハッシュを結合
        imageHashes = verifiedHashes.union(unverifiedHashes)

        print("✅ 重複チェッカーの初期化が完了しました")
        print("確認済みデータセット: \(verifiedHashes.count)件")
        print("未確認データセット: \(unverifiedHashes.count)件")
        print("合計: \(imageHashes.count)件")
    }

    private func loadHashesFromDirectory(isVerified: Bool) async throws -> Set<String> {
        var hashes = Set<String>()
        let directory = isVerified ? "Dataset/Verified" : "Dataset/Unverified"

        // ディレクトリとそのサブディレクトリ内のすべての画像ファイルを取得
        let files = try await fileManager.getAllImageFiles(in: directory)

        for file in files {
            let fileURL = URL(fileURLWithPath: file)
            do {
                let imageData = try await imageLoader.loadLocalImage(from: fileURL)
                let hash = calculateImageHash(imageData)
                hashes.insert(hash)
            } catch {
                print("❌ 画像の読み込みに失敗: \(file) - \(error)")
            }
        }

        return hashes
    }

    /// 画像が重複しているかチェック、重複がない場合はtrue、重複がある場合はfalseを返す
    public func checkDuplicate(imageData: Data, fileName: String, label: String) async throws -> Bool {
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
            print("⚠️ ファイル名の重複を検出したので、保存をスキップ: \(fileName)")
            return false
        }

        // 次に、画像コンテンツのハッシュが存在するかチェック
        let hash = calculateImageHash(imageData)
        if imageHashes.contains(hash) {
            print("⚠️ 画像内容の重複を検出したので、保存をスキップ: \(fileName)")
            return false
        }

        return true
    }

    /// 新しい画像のハッシュを追加する
    /// - Parameter imageData: 追加する画像データ
    public func addHash(imageData: Data) async {
        let hash = calculateImageHash(imageData)
        imageHashes.insert(hash)
    }

    private func calculateImageHash(_ imageData: Data) -> String {
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
