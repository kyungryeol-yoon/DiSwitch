// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DisplayInputSwitch",
  platforms: [.macOS(.v15)],
  targets: [
    .executableTarget(
      name: "DisplayInputSwitch",
      path: "Sources/DisplayInputSwitch",
      linkerSettings: [.linkedFramework("IOKit")]
    )
  ],
  swiftLanguageModes: [.v5]
)
