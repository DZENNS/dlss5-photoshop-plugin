// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "DLSSPhotoshop",
    platforms: [.macOS("15.8")],
    products: [.library(name: "DLSSPhotoshopNative", type: .dynamic, targets: ["PhotoshopNative"])],
    dependencies: [.package(path: "Vendor/MLX-DLSS")],
    targets: [
        .target(name: "ScreenCore"),
        .target(name: "PhotoshopNative", dependencies: ["ScreenCore", .product(name: "DLSSCore", package: "MLX-DLSS"), .product(name: "DLSSMLX", package: "MLX-DLSS"), .product(name: "DLSSMedia", package: "MLX-DLSS")], resources: [.copy("Shaders.metal")]),
        .testTarget(name: "ScreenCoreTests", dependencies: ["ScreenCore"])
    ], swiftLanguageModes: [.v5])
