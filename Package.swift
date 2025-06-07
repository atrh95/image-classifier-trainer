// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LabeledDatasetCurator",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "LabeledDatasetCurator", targets: [
            "SLFileManager",
            "SLImageLoader",
            "SLDuplicateChecker",
            "SLClassifier",
            "CatAPIClient",
        ]),
        .library(name: "SLFileManager", targets: ["SLFileManager"]),
        .library(name: "SLImageLoader", targets: ["SLImageLoader"]),
        .library(name: "SLDuplicateChecker", targets: ["SLDuplicateChecker"]),
        .library(name: "SLClassifier", targets: ["SLClassifier"]),
        .library(name: "CatAPIClient", targets: ["CatAPIClient"]),
    ],
    targets: [
        .target(
            name: "SLFileManager",
            path: "SLFileManager/Sources"
        ),
        .testTarget(
            name: "SLFileManagerTests",
            dependencies: ["SLFileManager"],
            path: "SLFileManager/Tests"
        ),
        .target(
            name: "SLImageLoader",
            path: "SLImageLoader/Sources"
        ),
        .target(
            name: "SLDuplicateChecker",
            dependencies: ["SLFileManager"],
            path: "SLDuplicateChecker/Sources"
        ),
        .testTarget(
            name: "SLDuplicateCheckerTests",
            dependencies: ["SLDuplicateChecker", "SLFileManager"],
            path: "SLDuplicateChecker/Tests"
        ),
        .target(
            name: "SLClassifier",
            dependencies: [
                "SLFileManager",
                "SLImageLoader",
            ],
            path: "SLClassifier/Sources"
        ),
        .testTarget(
            name: "SLClassifierTests",
            dependencies: [
                "SLClassifier",
                "SLFileManager",
                "SLImageLoader",
            ],
            path: "SLClassifier/Tests"
        ),
        .target(
            name: "CatAPIClient",
            path: "CatAPIClient/Sources"
        ),
    ]
)
