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
  dependencies: [],
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
