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
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.4"),
  ],
  targets: [
    .target(
      name: "GameCenterKit",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .testTarget(
      name: "GameCenterKitTests",
      dependencies: ["GameCenterKit"]
    ),
  ]
)
