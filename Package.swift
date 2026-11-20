// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DiSwitch",
  platforms: [.macOS(.v15)],
  targets: [
    .executableTarget(
      name: "DiSwitch",
      path: "Sources/DiSwitch",
      linkerSettings: [.linkedFramework("IOKit")]
    )
  ],
  swiftLanguageModes: [.v5]
)
