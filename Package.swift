// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Squid",
    platforms: [
        .macOS(.v10_15), .iOS(.v13)
    ],
    products: [
        .library(name: "Squid", xtargets: ["Squid"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git",
                 .branch("feature/spm-support"))
    ],
    targets: [
        .target(name: "Squid", dependencies: []),
        .testTarget(name: "SquidTests", dependencies: ["Squid", "OHHTTPStubsSwift"]),
    ]
)
