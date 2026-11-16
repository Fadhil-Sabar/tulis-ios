// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Tulis",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // xtool: tepat satu library product, yaitu aplikasinya.
        .library(name: "Tulis", targets: ["Tulis"]),
    ],
    targets: [
        // Antarmuka iOS (SwiftUI + PencilKit).
        .target(name: "Tulis", dependencies: ["TulisCore"]),
        // Model dan format file, hanya Foundation, jalan juga di Linux.
        .target(name: "TulisCore"),
        .testTarget(name: "TulisCoreTests", dependencies: ["TulisCore"]),
    ]
)
