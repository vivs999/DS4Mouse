// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DS4Mouse",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "DS4Core", targets: ["DS4Core"]),
    .executable(name: "DS4Probe", targets: ["DS4Probe"]),
    .executable(name: "DS4MouseApp", targets: ["DS4App"]),
    .executable(name: "ds4mouse", targets: ["DS4CLI"]),
  ],
  targets: [
    .target(name: "DS4Core"),
    .target(name: "DS4Platform", dependencies: ["DS4Core"]),
    .executableTarget(name: "DS4Probe", dependencies: ["DS4Core", "DS4Platform"]),
    .executableTarget(name: "DS4App", dependencies: ["DS4Core", "DS4Platform"]),
    .executableTarget(name: "DS4CLI", dependencies: ["DS4Core", "DS4Platform"]),
    .testTarget(name: "DS4CoreTests", dependencies: ["DS4Core"]),
    .testTarget(name: "DS4PlatformTests", dependencies: ["DS4Core", "DS4Platform"]),
  ]
)
