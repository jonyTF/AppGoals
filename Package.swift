// swift-tools-version: 6.0
import PackageDescription

// Foundation-only models and API clients can be tested without an iOS simulator.
let package = Package(
    name: "AppGoalsCore",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "AppGoalsCore",
            path: "AppGoals/Shared",
            exclude: ["KeychainStore.swift", "LabeledProgressBar.swift", "ProgressRing.swift", "PrivacyInfo.xcprivacy"]
        ),
        .testTarget(name: "AppGoalsCoreTests", dependencies: ["AppGoalsCore"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
