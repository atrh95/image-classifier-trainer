import Foundation

/// 画像の重複チェックを行うプロトコル
protocol DuplicateCheckerProtocol {
    /// 既存の画像ハッシュを初期化する
    func initializeHashes() async throws
    
    /// 画像が重複しているかチェック、重複がない場合はtrue、重複がある場合はfalseを返す
    func checkDuplicate(imageData: Data, fileName: String, label: String) async throws -> Bool
    
    /// 新しい画像のハッシュを追加する
    func addHash(imageData: Data) async
} 