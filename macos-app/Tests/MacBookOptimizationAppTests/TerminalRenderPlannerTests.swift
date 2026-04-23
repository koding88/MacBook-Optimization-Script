import XCTest
@testable import MacBookOptimizationApp

final class TerminalRenderPlannerTests: XCTestCase {
    func testKeyChangeAnimatesFreshRenderFromEmptyState() {
        let strategy = TerminalRenderPlanner.strategy(
            current: "old output",
            incoming: "new output",
            keyChanged: true
        )

        XCTAssertEqual(strategy, .animate(from: "", to: "new output"))
    }

    func testAppendOnlyOutputAnimatesSuffixInsteadOfReplacing() {
        let strategy = TerminalRenderPlanner.strategy(
            current: "line 1",
            incoming: "line 1\nline 2",
            keyChanged: false
        )

        XCTAssertEqual(strategy, .animate(from: "line 1", to: "line 1\nline 2"))
    }

    func testChangedOutputWithoutSharedPrefixReplacesImmediately() {
        let strategy = TerminalRenderPlanner.strategy(
            current: "cpu output",
            incoming: "memory output",
            keyChanged: false
        )

        XCTAssertEqual(strategy, .replace("memory output"))
    }

    func testCommandPreviewFormatsShellBlocksIntoIndentedLines() {
        let preview = TerminalDisplayFormatter.formatCommandPreview(
            "if [ -f /etc/hosts ]; then printf 'found'; else printf 'missing'; fi"
        )

        XCTAssertTrue(preview.contains("if [ -f /etc/hosts ];"))
        XCTAssertTrue(preview.contains("\nthen\n  printf 'found';"))
        XCTAssertTrue(preview.contains("\nelse\n  printf 'missing';"))
        XCTAssertTrue(preview.contains("\nfi"))
    }

    func testCommandPreviewSeparatesBraceBlocksAndPipelines() {
        let preview = TerminalDisplayFormatter.formatCommandPreview(
            "restore_hosts() { cat \"$tmp_backup\" > /etc/hosts; dscacheutil -flushcache; }; grep foo /etc/hosts | awk '{print $1}'"
        )

        XCTAssertTrue(preview.contains("restore_hosts() {"))
        XCTAssertTrue(preview.contains("\n  cat \"$tmp_backup\" > /etc/hosts;"))
        XCTAssertTrue(preview.contains("\n  dscacheutil -flushcache;"))
        XCTAssertTrue(preview.contains("\n};"))
        XCTAssertTrue(preview.contains("\ngrep foo /etc/hosts |"))
    }
}
