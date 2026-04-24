import XCTest
@testable import MacBookOptimizationApp

final class CPUMonitoringServiceTests: XCTestCase {
    func testMonitoringShellCommandUsesConfiguredIntervalInsteadOfHardcodedOneSecond() {
        let command = CPUMonitoringService.monitoringShellCommand(
            outputFilePath: "/tmp/output.log",
            stopFilePath: "/tmp/stop.flag",
            sampleIntervalMilliseconds: 5_000
        )

        XCTAssertTrue(command.contains("-i \"$2\""))
        XCTAssertTrue(command.contains("sh \"$stop_file\" 5000"))
        XCTAssertFalse(command.contains(" -i 1000 "))
        XCTAssertFalse(command.contains("nohup"))
        XCTAssertTrue(command.contains("</dev/null & printf 'started\\n'"))
    }

    func testLastCompleteSampleReturnsMostRecentFinishedBlock() {
        let output = """
        first line
        __MBO_SAMPLE_END__
        second line
        __MBO_SAMPLE_END__
        partial
        """

        let sample = CPUMonitoringService.lastCompleteSample(
            in: output,
            delimiter: "\n__MBO_SAMPLE_END__\n"
        )

        XCTAssertEqual(sample, "second line")
    }
}
