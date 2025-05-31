import Foundation
import CryptoKit
import CTFileManager

actor DuplicateImageScanner {
    private let fileManager: CTFileManagerProtocol
    private var imageHashes: [String: [String]] = [:] // ハッシュ値とファイルパスのマッピング
    
    /// 対応している画像拡張子
    private let supportedExtensions = ["jpg", "jpeg", "png"]

    init(fileManager: CTFileManagerProtocol) {
        self.fileManager = fileManager
    }

    /// 画像データのハッシュ値を計算
    private func calculateImageHash(_ imageData: Data) -> String {
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 指定されたディレクトリ内の画像をスキャンして重複を検出
    func scanDirectory(_ unverifiedDirectory: URL) async throws -> Int {
        let fileManager = FileManager.default
        
        // Verifiedディレクトリのパスを取得
        let verifiedDirectory = unverifiedDirectory.deletingLastPathComponent().appendingPathComponent("Verified")
        
        print("\n🔍 重複画像の検出を開始...")
        print("   スキャン対象:")
        print("   - Unverified: \(unverifiedDirectory.path)")
        print("   - Verified: \(verifiedDirectory.path)")
        print()

        // まずVerifiedディレクトリのハッシュ値を収集
        print("📁 Verifiedディレクトリのスキャン中...")
        if fileManager.fileExists(atPath: verifiedDirectory.path) {
            let verifiedEnumerator = fileManager.enumerator(
                at: verifiedDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            while let fileURL = verifiedEnumerator?.nextObject() as? URL {
                guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                
                do {
                    let imageData = try Data(contentsOf: fileURL)
                    let imageHash = calculateImageHash(imageData)
                    var paths = imageHashes[imageHash] ?? []
                    paths.append(fileURL.path)
                    imageHashes[imageHash] = paths
                } catch {
                    print("⚠️ ファイルの読み込みに失敗: \(fileURL.path)")
                }
            }
        }
        
        // Unverifiedディレクトリのラベルを取得
        let labelDirectories = try fileManager.contentsOfDirectory(
            at: unverifiedDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }

        var totalDuplicates = 0
        var totalScannedFiles = 0

        // 各ラベルディレクトリに対して処理を実行
        for labelDir in labelDirectories {
            let label = labelDir.lastPathComponent
            print("\n📁 ラベル「\(label)」の処理を開始...")
            
            let enumerator = fileManager.enumerator(
                at: labelDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            var labelDuplicates = 0
            var scannedFiles = 0

            while let fileURL = enumerator?.nextObject() as? URL {
                guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                scannedFiles += 1

                do {
                    let imageData = try Data(contentsOf: fileURL)
                    let imageHash = calculateImageHash(imageData)
                    
                    // ハッシュ値に対応するファイルパスを追加
                    var paths = imageHashes[imageHash] ?? []
                    paths.append(fileURL.path)
                    imageHashes[imageHash] = paths
                } catch {
                    print("⚠️ ファイルの読み込みに失敗: \(fileURL.path)")
                }
            }

            // このラベルの重複を検出して表示
            for (hash, paths) in imageHashes where paths.count > 1 {
                // このラベルディレクトリ内の重複を処理
                let labelPaths = paths.filter { $0.contains("/\(label)/") }
                guard labelPaths.count > 1 else { continue }
                
                // Verifiedとの重複をチェック
                let verifiedPaths = paths.filter { $0.contains("/Verified/") }
                if !verifiedPaths.isEmpty {
                    // Verifiedの画像が存在する場合、Unverifiedの重複を削除
                    print("\n⚠️ Verifiedとの重複を検出:")
                    print("  Verified内の画像:")
                    for path in verifiedPaths {
                        print("  - \(path)")
                    }
                    print("  Unverified内の重複（削除）:")
                    for path in labelPaths {
                        do {
                            try fileManager.removeItem(atPath: path)
                            print("  - 削除: \(path)")
                            labelDuplicates += 1
                        } catch {
                            print("  - ⚠️ 削除失敗: \(path) - \(error.localizedDescription)")
                        }
                    }
                } else {
                    // Unverified内での重複のみの場合
                    labelDuplicates += labelPaths.count - 1
                    print("\n重複グループ:")
                    let keepPath = labelPaths[0]
                    let deletePaths = Array(labelPaths[1...])
                    
                    print("  保持: \(keepPath)")
                    for path in deletePaths {
                        do {
                            try fileManager.removeItem(atPath: path)
                            print("  削除: \(path)")
                        } catch {
                            print("  ⚠️ 削除失敗: \(path) - \(error.localizedDescription)")
                        }
                    }
                }
            }

            if labelDuplicates > 0 {
                print("\n📊 ラベル「\(label)」の処理結果:")
                print("   スキャンした画像: \(scannedFiles)枚")
                print("   削除した画像: \(labelDuplicates)枚")
            } else {
                print("   重複は見つかりませんでした。")
            }
            
            totalDuplicates += labelDuplicates
            totalScannedFiles += scannedFiles
            print("----------------------------------------")
        }

        // 全体の結果を表示
        print("\n📊 全体の処理結果:")
        print("   スキャンした画像: \(totalScannedFiles)枚")
        print("   削除した画像: \(totalDuplicates)枚")
        
        return totalDuplicates
    }
} 