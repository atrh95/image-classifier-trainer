import Foundation

public final class MockCTImageLoader: CTImageLoaderProtocol {
    private let sampleImagesDirectory: URL
    public var testImageURL: URL {
        sampleImagesDirectory.appendingPathComponent("MTU1MDA0NA.jpg")
    }
    
    public var mockLocalImageData: [URL: Data] = [:]
    public var mockLoadLocalImageError: Error?

    public init() {
        // サンプル画像ディレクトリのパスを設定
        let currentFileURL = URL(fileURLWithPath: #filePath)
        sampleImagesDirectory = currentFileURL
            .deletingLastPathComponent() // CTImageLoader
            .appendingPathComponent("SampleImage")
    }

    public func downloadImage(from _: URL) async throws -> Data {
        // サンプル画像ディレクトリから画像を読み込む
        guard let imageData = try? Data(contentsOf: testImageURL) else {
            throw ImageLoaderError.sampleImageNotFound
        }

        return imageData
    }
    
    public func loadLocalImage(from url: URL) async throws -> Data {
        if let error = mockLoadLocalImageError {
            throw error
        }
        
        if let mockData = mockLocalImageData[url] {
            return mockData
        }
        
        // デフォルトのサンプル画像データを返す
        guard let imageData = try? Data(contentsOf: testImageURL) else {
            throw ImageLoaderError.sampleImageNotFound
        }
        
        return imageData
    }
}
