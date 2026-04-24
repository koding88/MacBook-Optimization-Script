import XCTest
@testable import MacBookOptimizationApp

final class GPUSnapshotCollectorTests: XCTestCase {
    func testParseSystemProfilerPayloadBuildsGPUDevicesAndDisplays() throws {
        let data = """
        {
          "SPDisplaysDataType" : [
            {
              "_name" : "spdisplays_builtin",
              "sppci_model" : "Apple M4",
              "spdisplays_metal" : "Supported, feature set macOS GPUFamily2 v1",
              "spdisplays_ndrvs" : [
                {
                  "_name" : "Built-in Liquid Retina XDR Display",
                  "_spdisplays_pixels" : "3456 x 2234",
                  "spdisplays_online" : "spdisplays_yes",
                  "spdisplays_main" : "spdisplays_yes"
                },
                {
                  "_name" : "Studio Display",
                  "_spdisplays_pixels" : "5120 x 2880",
                  "spdisplays_online" : "spdisplays_yes"
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let entries = try XCTUnwrap(SystemProfilerJSONReader.entries(in: data, for: "SPDisplaysDataType"))
        let snapshot = GPUSnapshotCollector.systemProfilerSnapshot(from: entries)

        XCTAssertEqual(snapshot.devices.count, 1)
        XCTAssertEqual(snapshot.devices.first?.name, "Apple M4")
        XCTAssertEqual(snapshot.devices.first?.metalSupport, "Supported, feature set macOS GPUFamily2 v1")
        XCTAssertEqual(snapshot.devices.first?.displayCount, 2)
        XCTAssertEqual(snapshot.displays.count, 2)
        XCTAssertEqual(snapshot.displays.first?.name, "Built-in Liquid Retina XDR Display")
        XCTAssertEqual(snapshot.displays.first?.resolution, "3456 × 2234")
        XCTAssertEqual(snapshot.displays.first?.isOnline, true)
        XCTAssertEqual(snapshot.displays.first?.isMain, true)
    }

    func testParseSystemProfilerMetal3AndEnrichedDisplayFields() throws {
        let data = """
        {
          "SPDisplaysDataType" : [
            {
              "_name" : "Apple M2 Pro",
              "spdisplays_mtlgpufamilysupport" : "spdisplays_metal3",
              "spdisplays_ndrvs" : [
                {
                  "_name" : "Color LCD",
                  "_spdisplays_pixels" : "2992 x 1934",
                  "_spdisplays_resolution" : "1496 x 967 @ 120.00Hz",
                  "spdisplays_main" : "spdisplays_yes",
                  "spdisplays_online" : "spdisplays_yes",
                  "spdisplays_display_type" : "spdisplays_built-in-liquid-retina-xdr",
                  "spdisplays_pixelresolution" : "spdisplays_3456x2234Retina"
                }
              ],
              "sppci_model" : "Apple M2 Pro"
            }
          ]
        }
        """.data(using: .utf8)!

        let entries = try XCTUnwrap(SystemProfilerJSONReader.entries(in: data, for: "SPDisplaysDataType"))
        let snapshot = GPUSnapshotCollector.systemProfilerSnapshot(from: entries)

        XCTAssertEqual(snapshot.devices.first?.metalSupport, "Metal 3")
        XCTAssertEqual(snapshot.displays.first?.refreshRate, "120Hz")
        XCTAssertEqual(snapshot.displays.first?.scaleDescription, "1496 × 967 scaled")
        XCTAssertEqual(snapshot.displays.first?.supportsHDR, true)
        XCTAssertEqual(snapshot.displays.first?.supportsProMotion, true)
    }

    func testCollectorFallsBackToMetalSnapshotWhenSystemProfilerUnavailable() throws {
        let metalDevice = GPUMetalDeviceSnapshot(
            registryID: 7,
            name: "Apple M3 Max",
            isLowPower: false,
            isRemovable: false,
            hasUnifiedMemory: true,
            recommendedMaxWorkingSetSize: 51_539_607_552,
            maxThreadsPerThreadgroup: .init(width: 1024, height: 1024, depth: 1024),
            supportsFeatureSetFallback: true,
            supportedFamilies: ["Apple7", "Mac2"]
        )
        let collector = GPUSnapshotCollector(
            systemProfilerEntriesProvider: { _ in nil },
            metalDevicesProvider: { [metalDevice] },
            ioRegistryPropertiesProvider: { [] }
        )

        let snapshot = try collector.collectSnapshot()

        XCTAssertEqual(snapshot.devices.first?.name, "Apple M3 Max")
        XCTAssertEqual(snapshot.devices.first?.source, .metal)
        XCTAssertEqual(snapshot.devices.first?.recommendedMaxWorkingSetSizeBytes, 51_539_607_552)
        XCTAssertEqual(snapshot.devices.first?.supportedFamilies, ["Apple7", "Mac2"])
        XCTAssertTrue(snapshot.liveTelemetry.isPubliclyUnavailable)
    }

    func testCollectorMergesSystemProfilerAndMetalByName() throws {
        let collector = GPUSnapshotCollector(
            systemProfilerEntriesProvider: { _ in
                [
                    [
                        "sppci_model": "Apple M3 Pro",
                        "spdisplays_metal": "Supported, feature set macOS GPUFamily2 v1",
                        "spdisplays_ndrvs": [
                            [
                                "_name": "Built-in Display",
                                "_spdisplays_pixels": "3024 x 1964",
                                "spdisplays_online": "spdisplays_yes",
                                "spdisplays_main": "spdisplays_yes"
                            ]
                        ]
                    ]
                ]
            },
            metalDevicesProvider: {
                [
                    GPUMetalDeviceSnapshot(
                        registryID: 2,
                        name: "Apple M3 Pro",
                        isLowPower: false,
                        isRemovable: false,
                        hasUnifiedMemory: true,
                        recommendedMaxWorkingSetSize: 18_000_000_000,
                        maxThreadsPerThreadgroup: .init(width: 1024, height: 1024, depth: 64),
                        supportsFeatureSetFallback: true,
                        supportedFamilies: ["Apple8", "Mac2"]
                    )
                ]
            },
            ioRegistryPropertiesProvider: { [] }
        )

        let snapshot = try collector.collectSnapshot()

        XCTAssertEqual(snapshot.devices.count, 1)
        XCTAssertEqual(snapshot.devices.first?.name, "Apple M3 Pro")
        XCTAssertEqual(snapshot.devices.first?.source, .merged)
        XCTAssertEqual(snapshot.devices.first?.displayCount, 1)
        XCTAssertEqual(snapshot.devices.first?.supportsFeatureSetFallback, true)
        XCTAssertEqual(snapshot.devices.first?.supportedFamilies, ["Apple8", "Mac2"])
        XCTAssertEqual(snapshot.displays.first?.resolution, "3024 × 1964")
    }
}
