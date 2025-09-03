// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "GameCenterKit",
  platforms: [
    .iOS(.v18)
  ],
  products: [
    .library(
      name: "GameCenterKit",
      targets: ["GameCenterKit"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.55.0")
  ],
  targets: [
    .target(
      name: "GameCenterKit"
    ),
    .testTarget(
      name: "GameCenterKitTests",
      dependencies: ["GameCenterKit"]
    ),
  ]
)
