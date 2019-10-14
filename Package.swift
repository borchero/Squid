// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Squid",
    platforms: [
        .macOS(.v10_15), .iOS(.v13)
    ],
    products: [
        .library(name: "Squid", targets: ["Squid"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git",
                 .revision("fda9902f8c5c4170c6914d7dc845174e8c75bf92"))
    ],
    targets: [
        .target(name: "Squid", dependencies: []),
        .testTarget(name: "SquidTests", dependencies: ["Squid", "OHHTTPStubsSwift"]),
    ]
)
