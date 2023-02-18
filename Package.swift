// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CoreDataModelInteractor",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "CoreDataModelInteractor",
            targets: ["CoreDataModelInteractor"]),
    ],
    targets: [
        .target(
            name: "CoreDataModelInteractor",
            dependencies: []
        ),
        .testTarget(
            name: "CoreDataModelInteractorTests",
            dependencies: ["CoreDataModelInteractor"]
        ),
    ]
)
