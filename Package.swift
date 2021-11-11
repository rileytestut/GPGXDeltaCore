// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GPGXDeltaCore",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "GPGXDeltaCore",
            type: .dynamic,
            targets: ["GPGXDeltaCore"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/rileytestut/DeltaCore.git", .branch("swiftpm"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "GPGXDeltaCore",
            dependencies: ["DeltaCore", "GenesisPlusGX", "GPGXSwift", "GPGXBridge"],
            exclude: [
                "Resources/Controller Skin/info.json",
                "Resources/Controller Skin/iphone_portrait.pdf",
                "Resources/Controller Skin/iphone_landscape.pdf",
                "Resources/Controller Skin/iphone_edgetoedge_portrait.pdf",
                "Resources/Controller Skin/iphone_edgetoedge_landscape.pdf"
            ],
            resources: [
                .copy("Resources/Controller Skin/Standard.deltaskin"),
                .copy("Resources/Standard.deltamapping"),
            ]
        ),
        .target(
            name: "GPGXSwift",
            dependencies: ["DeltaCore"]
        ),
        .target(
            name: "GPGXBridge",
            dependencies: ["DeltaCore", "GenesisPlusGX", "GPGXSwift"],
            publicHeadersPath: "",
            cSettings: [
                .headerSearchPath("../GenesisPlusGX/Genesis-Plus-GX/core"),
                .headerSearchPath("../GenesisPlusGX/Genesis-Plus-GX/core/m68k"),
                .headerSearchPath("../GenesisPlusGX/Genesis-Plus-GX/core/z80"),
                .headerSearchPath("../GenesisPlusGX/Genesis-Plus-GX/core/sound"),
                .headerSearchPath("../GenesisPlusGX/Genesis-Plus-GX/core/cart_hw"),
                .headerSearchPath("../GenesisPlusGX/Genesis-Plus-GX/core/cart_hw/svp"),
                .headerSearchPath("../GenesisPlusGX/Genesis-Plus-GX/core/cd_hw"),
                .headerSearchPath("../GenesisPlusGX/Genesis-Plus-GX/core/input_hw"),
                .headerSearchPath("../GenesisPlusGX/Genesis-Plus-GX/core/ntsc"),
                
                .headerSearchPath("../GenesisPlusGX/Genesis-Plus-GX/psp2"),
                
                .define("USE_32BPP_RENDERING"),
                .define("FLAC__HAS_OGG", to: "0"),
                .define("HAVE_SYS_PARAM_H"),
                .define("HAVE_LROUND"),
                .define("PACKAGE_VERSION", to: "\"1.3.2\""),
                .define("_7ZIP_ST"),
                .define("LSB_FIRST")
            ]
        ),
        .target(
            name: "GenesisPlusGX",
            exclude: [
                "Genesis-Plus-GX/builds",
                "Genesis-Plus-GX/gx",
                "Genesis-Plus-GX/libretro",
                "Genesis-Plus-GX/sdl",
                
                "Genesis-Plus-GX/gcw0/opk-data",
                
                "Genesis-Plus-GX/core/tremor",
                "Genesis-Plus-GX/libretro/tremor",
                
                "Genesis-Plus-GX/core/cd_hw/libchdr",
                
                "Genesis-Plus-GX/core/cart_hw/svp/imageformat.txt",
                "Genesis-Plus-GX/core/cart_hw/svp/svpdoc.txt",
                
                "Genesis-Plus-GX/core/m68k/readme.txt",
                
                "Genesis-Plus-GX/core/ntsc/changes.txt",
                "Genesis-Plus-GX/core/ntsc/license.txt",
                "Genesis-Plus-GX/core/ntsc/readme.txt",
                "Genesis-Plus-GX/core/ntsc/sms_ntsc.txt",
                
                "Genesis-Plus-GX/psp2/db.json",
                "Genesis-Plus-GX/psp2/emumain.c",
                "Genesis-Plus-GX/psp2/error.c",
                "Genesis-Plus-GX/psp2/fileio.c",
                "Genesis-Plus-GX/psp2/Makefile",
                "Genesis-Plus-GX/psp2/main.c",
                "Genesis-Plus-GX/psp2/menu.c",
                "Genesis-Plus-GX/psp2/unzip.c",
                
                "Genesis-Plus-GX/gcw0/config.c",
                "Genesis-Plus-GX/gcw0/error.c",
                "Genesis-Plus-GX/gcw0/main.c",
                "Genesis-Plus-GX/gcw0/Makefile",
                "Genesis-Plus-GX/gcw0/opk_build.sh",
                "Genesis-Plus-GX/gcw0/utils.c",
                
                "Genesis-Plus-GX/appveyor.yml",
                "Genesis-Plus-GX/HISTORY.txt",
                "Genesis-Plus-GX/LICENSE.txt",
                "Genesis-Plus-GX/Makefile.gc",
                "Genesis-Plus-GX/Makefile.libretro",
                "Genesis-Plus-GX/Makefile.wii",
                "Genesis-Plus-GX/README.md",
            ],
            sources: [
                "Genesis-Plus-GX/core",
                
                "Genesis-Plus-GX/psp2/config.c",
                
                "Genesis-Plus-GX/gcw0/fileio.c",
                "Genesis-Plus-GX/gcw0/unzip.c",
            ],
            cSettings: [
                .headerSearchPath("Genesis-Plus-GX/core"),
                .headerSearchPath("Genesis-Plus-GX/core/m68k"),
                .headerSearchPath("Genesis-Plus-GX/core/z80"),
                .headerSearchPath("Genesis-Plus-GX/core/sound"),
                .headerSearchPath("Genesis-Plus-GX/core/cart_hw"),
                .headerSearchPath("Genesis-Plus-GX/core/cart_hw/svp"),
                .headerSearchPath("Genesis-Plus-GX/core/cd_hw"),
                .headerSearchPath("Genesis-Plus-GX/core/cd_hw/libchdr/deps/lzma"),
                .headerSearchPath("Genesis-Plus-GX/core/cd_hw/libchdr/deps/libFLAC/include"),
                .headerSearchPath("Genesis-Plus-GX/core/input_hw"),
                .headerSearchPath("Genesis-Plus-GX/core/ntsc"),
                
                .headerSearchPath("Genesis-Plus-GX/psp2"),
                
                .define("USE_32BPP_RENDERING"),
                .define("FLAC__HAS_OGG", to: "0"),
                .define("HAVE_SYS_PARAM_H"),
                .define("HAVE_LROUND"),
                .define("PACKAGE_VERSION", to: "\"1.3.2\""),
                .define("_7ZIP_ST"),
                .define("LSB_FIRST")
            ]
        )
    ]
)
