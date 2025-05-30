import Foundation

public struct CatImageURLModel: Codable {
    public let id: String
    public let url: String
    public let width: Int
    public let height: Int

    public init(id: String, url: String, width: Int, height: Int) {
        self.id = id
        self.url = url
        self.width = width
        self.height = height
    }
}
