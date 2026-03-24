// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-mail-core",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MailCore",
            targets: ["MailCore"]
        ),
        .library(
            name: "MailCoreSMTP",
            targets: ["MailCoreSMTP"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "MailCore",
            dependencies: [
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ],
            path: "Sources/MailCore"
        ),
        .target(
            name: "MailCoreSMTP",
            dependencies: ["MailCore"],
            path: "Sources/MailCoreSMTP"
        ),
        .testTarget(
            name: "MailCoreTests",
            dependencies: ["MailCore", "MailCoreSMTP"],
            path: "Tests/MailCoreTests"
        ),
    ]
)
