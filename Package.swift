// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LLMKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "LLMKit",
            targets: ["LLMKit", "LLMKitUI"]
        ),
    ],
    dependencies: [
        // 🔥 Arquitetura Segura: Travamos num commit testado do llama.cpp que suporta o Metal perfeitamente!
        .package(url: "https://github.com/ggerganov/llama.cpp.git", revision: "b6d6c5289f1c9c677657c380591201ddb210b649")
    ],
    targets: [
        .target(
            name: "LLMKit",
            dependencies: [
                .product(name: "llama", package: "llama.cpp")
            ],
            path: "Sources/LLMKit"
        ),
        .target(
            name: "LLMKitUI",
            dependencies: ["LLMKit"],
            path: "Sources/LLMKitUI"
        ),
        .testTarget(
            name: "LLMKitTests",
            dependencies: ["LLMKit"],
            path: "Tests/LLMKitTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
