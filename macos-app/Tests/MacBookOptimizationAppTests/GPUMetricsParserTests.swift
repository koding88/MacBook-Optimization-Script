import XCTest
@testable import MacBookOptimizationApp

final class GPUMetricsParserTests: XCTestCase {
    private let samplePlistData = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>gpu_power</key>
        <real>412.6</real>
        <key>gpu_frequency_mhz</key>
        <integer>744</integer>
        <key>tasks</key>
        <array>
            <dict>
                <key>name</key>
                <string>WindowServer</string>
                <key>gpu_ms_s</key>
                <real>185.4</real>
            </dict>
            <dict>
                <key>name</key>
                <string>Safari</string>
                <key>gpu_ms_s</key>
                <real>41.2</real>
            </dict>
        </array>
    </dict>
    </plist>
    """.data(using: .utf8)!

    func testParseTextSampleBuildsRuntimeMetricsFromPowermetricsOutput() {
        let output = """
        *** Sampled system activity (5000ms elapsed) ***
        GPU Power: 415 mW
        GPU Frequency: 735 MHz

        *** Running tasks ***
        Name                               ID     CPU ms/s  User%  Deadlines (<2 ms, 2-5 ms)  Wakeups (Intr, Pkg idle)  GPU ms/s
        WindowServer                       88     44.62                                       90.14   31.20             221.74
          Safari                           921    12.11                                       21.44    8.21             104.47
        """

        let metrics = GPUMetricsParser.parse(output)

        XCTAssertEqual(metrics?.powerMilliwatts, 415)
        XCTAssertEqual(metrics?.frequencyMHz, 735)
        XCTAssertEqual(metrics?.processes.first?.name, "WindowServer")
        XCTAssertEqual(metrics?.processes.first?.gpuMillisecondsPerSecond ?? -1, 221.74, accuracy: 0.001)
        XCTAssertEqual(metrics?.usagePercent ?? -1, 32.6, accuracy: 0.1)
    }

    func testParseTextSampleConvertsWattsToMilliwatts() {
        let output = """
        GPU Power: 0.45 W
        *** Running tasks ***
        Name                               ID     CPU ms/s  GPU ms/s
        WindowServer                       88     10.00     50.00
        """

        let metrics = GPUMetricsParser.parse(output)

        XCTAssertEqual(metrics?.powerMilliwatts, 450)
    }

    func testParseReturnsNilWhenNoGpuFieldsExist() {
        XCTAssertNil(GPUMetricsParser.parse("CPU Power: 500 mW"))
    }

    func testParsePlistBuildsRuntimeMetrics() {
        let metrics = GPUMetricsParser.parse(plistData: samplePlistData)

        XCTAssertEqual(metrics?.powerMilliwatts, 413)
        XCTAssertEqual(metrics?.frequencyMHz, 744)
        XCTAssertEqual(metrics?.processes.first?.name, "WindowServer")
        XCTAssertEqual(metrics?.processes.first?.gpuMillisecondsPerSecond ?? -1, 185.4, accuracy: 0.001)
        XCTAssertEqual(metrics?.usagePercent ?? -1, 22.66, accuracy: 0.1)
    }

    func testParsePlistSupportsNestedTaskShapesAndMemoryWhenPresent() {
        let plistData = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>gpu</key>
            <dict>
                <key>gpu_power_mw_avg</key>
                <integer>520</integer>
                <key>gpu_freq_mhz</key>
                <integer>800</integer>
                <key>gpu_memory_bytes</key>
                <integer>2147483648</integer>
            </dict>
            <key>processor</key>
            <dict>
                <key>tasks</key>
                <array>
                    <dict>
                        <key>process_name</key>
                        <string>WindowServer</string>
                        <key>gpu_ms_per_s</key>
                        <real>240.0</real>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>Safari</string>
                        <key>gpu_time_ms_s</key>
                        <real>60.0</real>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """.data(using: .utf8)!

        let metrics = GPUMetricsParser.parse(plistData: plistData)

        XCTAssertEqual(metrics?.powerMilliwatts, 520)
        XCTAssertEqual(metrics?.frequencyMHz, 800)
        XCTAssertEqual(metrics?.memoryBytes, 2_147_483_648)
        XCTAssertEqual(metrics?.processes.first?.name, "WindowServer")
        XCTAssertEqual(metrics?.processes.first?.gpuMillisecondsPerSecond ?? -1, 240.0, accuracy: 0.001)
        XCTAssertEqual(metrics?.usagePercent ?? -1, 30.0, accuracy: 0.1)
    }

    func testParsePlistSupportsRealGpuResidencyShapeWithoutProcessGpuFields() {
        let plistData = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>tasks</key>
            <array>
                <dict>
                    <key>pid</key>
                    <integer>169</integer>
                    <key>name</key>
                    <string>WindowServer</string>
                    <key>cputime_ms_per_s</key>
                    <real>192.7</real>
                </dict>
            </array>
            <key>gpu</key>
            <dict>
                <key>freq_hz</key>
                <real>444.0</real>
                <key>idle_ratio</key>
                <real>0.789012</real>
                <key>dvfm_states</key>
                <array>
                    <dict>
                        <key>freq</key>
                        <integer>444</integer>
                        <key>used_ratio</key>
                        <real>0.210988</real>
                    </dict>
                    <dict>
                        <key>freq</key>
                        <integer>612</integer>
                        <key>used_ratio</key>
                        <real>0.0</real>
                    </dict>
                </array>
                <key>gpu_energy</key>
                <integer>454</integer>
            </dict>
        </dict>
        </plist>
        """.data(using: .utf8)!

        let metrics = GPUMetricsParser.parse(plistData: plistData)

        XCTAssertEqual(metrics?.frequencyMHz, 444)
        XCTAssertEqual(metrics?.usagePercent ?? -1, 21.09, accuracy: 0.1)
        XCTAssertNil(metrics?.powerMilliwatts)
        XCTAssertTrue(metrics?.processes.isEmpty ?? false)
    }
}
