# Memory Snapshot Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the memory snapshot UI so it keeps the current layout while adopting brighter battery-style visuals, colored accents, and subtle update motion.

**Architecture:** Add a small presentation helper for memory snapshot visual decisions, cover it with focused tests, then wire those decisions into the existing `MemorySnapshotView` without changing the high-level layout. Keep the refresh isolated to presentation logic and SwiftUI styling so monitoring and metric collection behavior stay untouched.

**Tech Stack:** Swift, SwiftUI, Charts, XCTest

---

### Task 1: Add memory snapshot presentation tests

**Files:**

- Create: `macos-app/Tests/MacBookOptimizationAppTests/MemorySnapshotPresentationTests.swift`
- Modify: `macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotView.swift`
- Test: `macos-app/Tests/MacBookOptimizationAppTests/MemorySnapshotPresentationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MacBookOptimizationApp

final class MemorySnapshotPresentationTests: XCTestCase {
    func testChangedFieldsReturnsPressureAndUsageWhenPressureLevelAndUsedBytesChange() {
        let previous = MemoryMetrics(
            timestamp: Date(timeIntervalSince1970: 10),
            totalBytes: 16_000,
            appBytes: 5_000,
            wiredBytes: 1_000,
            compressedBytes: 500,
            cachedBytes: 6_000,
            freeBytes: 3_500,
            swapUsedBytes: 0,
            pageSizeBytes: 4_096
        )
        let current = MemoryMetrics(
            timestamp: Date(timeIntervalSince1970: 20),
            totalBytes: 16_000,
            appBytes: 7_000,
            wiredBytes: 2_000,
            compressedBytes: 1_000,
            cachedBytes: 4_000,
            freeBytes: 2_000,
            swapUsedBytes: 600,
            pageSizeBytes: 4_096
        )

        let changed = MemorySnapshotPresentation.changedFields(from: previous, to: current)

        XCTAssertEqual(changed, [.pressure, .usage, .swap])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path macos-app --filter MemorySnapshotPresentationTests/testChangedFieldsReturnsPressureAndUsageWhenPressureLevelAndUsedBytesChange`

Expected: FAIL with a missing `MemorySnapshotPresentation` symbol error.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

enum MemorySnapshotPresentation {
    enum ChangedField: Hashable {
        case pressure
        case usage
        case swap
    }

    static func changedFields(from previous: MemoryMetrics?, to current: MemoryMetrics) -> Set<ChangedField> {
        guard let previous else {
            return [.pressure, .usage, .swap]
        }

        var changedFields = Set<ChangedField>()

        if previous.pressureLevel != current.pressureLevel || abs(previous.pressureScore - current.pressureScore) >= 0.03 {
            changedFields.insert(.pressure)
        }

        if previous.usedBytes != current.usedBytes || previous.cachedBytes != current.cachedBytes {
            changedFields.insert(.usage)
        }

        if previous.swapUsedBytes != current.swapUsedBytes {
            changedFields.insert(.swap)
        }

        return changedFields
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path macos-app --filter MemorySnapshotPresentationTests/testChangedFieldsReturnsPressureAndUsageWhenPressureLevelAndUsedBytesChange`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add macos-app/Tests/MacBookOptimizationAppTests/MemorySnapshotPresentationTests.swift macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotPresentation.swift
git commit -m "test: add memory snapshot presentation coverage"
```

### Task 2: Expand presentation helper for visual decisions

**Files:**

- Modify: `macos-app/Tests/MacBookOptimizationAppTests/MemorySnapshotPresentationTests.swift`
- Modify: `macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotPresentation.swift`
- Test: `macos-app/Tests/MacBookOptimizationAppTests/MemorySnapshotPresentationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testHeaderAccentReturnsLivePaletteForNormalPressure() {
    let metrics = MemoryMetrics(
        timestamp: Date(timeIntervalSince1970: 20),
        totalBytes: 16_000,
        appBytes: 4_000,
        wiredBytes: 1_000,
        compressedBytes: 500,
        cachedBytes: 6_000,
        freeBytes: 4_500,
        swapUsedBytes: 0,
        pageSizeBytes: 4_096
    )

    let palette = MemorySnapshotPresentation.headerPalette(for: metrics)

    XCTAssertEqual(palette.iconSymbol, "memorychip.fill")
    XCTAssertEqual(palette.statusSymbol, "waveform.path.ecg")
    XCTAssertEqual(palette.emphasis, .normal)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path macos-app --filter MemorySnapshotPresentationTests/testHeaderAccentReturnsLivePaletteForNormalPressure`

Expected: FAIL with `headerPalette` or related palette type missing.

- [ ] **Step 3: Write minimal implementation**

```swift
extension MemorySnapshotPresentation {
    enum Emphasis: Equatable {
        case normal
        case warning
        case critical
    }

    struct HeaderPalette: Equatable {
        let iconSymbol: String
        let statusSymbol: String
        let emphasis: Emphasis
    }

    static func headerPalette(for metrics: MemoryMetrics) -> HeaderPalette {
        switch metrics.pressureLevel {
        case .normal:
            return HeaderPalette(iconSymbol: "memorychip.fill", statusSymbol: "waveform.path.ecg", emphasis: .normal)
        case .elevated:
            return HeaderPalette(iconSymbol: "memorychip.fill", statusSymbol: "exclamationmark.circle.fill", emphasis: .warning)
        case .critical:
            return HeaderPalette(iconSymbol: "memorychip.fill", statusSymbol: "flame.fill", emphasis: .critical)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path macos-app --filter MemorySnapshotPresentationTests/testHeaderAccentReturnsLivePaletteForNormalPressure`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add macos-app/Tests/MacBookOptimizationAppTests/MemorySnapshotPresentationTests.swift macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotPresentation.swift
git commit -m "feat: add memory snapshot visual palette helper"
```

### Task 3: Wire presentation helper into MemorySnapshotView refresh

**Files:**

- Modify: `macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotView.swift`
- Modify: `macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotPresentation.swift`
- Test: `macos-app/Tests/MacBookOptimizationAppTests/MemorySnapshotPresentationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testChangedFieldsDetectsInitialSnapshotAsAnimatedGroups() {
    let current = MemoryMetrics(
        timestamp: Date(timeIntervalSince1970: 20),
        totalBytes: 16_000,
        appBytes: 4_000,
        wiredBytes: 1_000,
        compressedBytes: 500,
        cachedBytes: 6_000,
        freeBytes: 4_500,
        swapUsedBytes: 0,
        pageSizeBytes: 4_096
    )

    let changed = MemorySnapshotPresentation.changedFields(from: nil, to: current)

    XCTAssertEqual(changed, [.pressure, .usage, .swap])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path macos-app --filter MemorySnapshotPresentationTests/testChangedFieldsDetectsInitialSnapshotAsAnimatedGroups`

Expected: FAIL if initial-state behavior does not match the agreed animation groups.

- [ ] **Step 3: Write minimal implementation**

```swift
@State private var previousMetrics: MemoryMetrics?
@State private var changedFields: Set<MemorySnapshotPresentation.ChangedField> = []

.onChange(of: viewModel.currentMetrics) { metrics in
    guard let metrics else { return }

    let updatedFields = MemorySnapshotPresentation.changedFields(from: previousMetrics, to: metrics)
    previousMetrics = metrics

    withAnimation(.easeInOut(duration: 0.24)) {
        changedFields = updatedFields
    }

    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(.easeOut(duration: 0.45)) {
            changedFields.subtract(updatedFields)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path macos-app --filter MemorySnapshotPresentationTests`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotView.swift macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotPresentation.swift macos-app/Tests/MacBookOptimizationAppTests/MemorySnapshotPresentationTests.swift
git commit -m "feat: animate memory snapshot updates"
```

### Task 4: Apply brighter battery-style visual treatment

**Files:**

- Modify: `macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotView.swift`
- Modify: `macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotPresentation.swift`
- Test: `macos-app/Tests/MacBookOptimizationAppTests/MemorySnapshotPresentationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testHeaderAccentReturnsCriticalPaletteForCriticalPressure() {
    let metrics = MemoryMetrics(
        timestamp: Date(timeIntervalSince1970: 20),
        totalBytes: 16_000,
        appBytes: 9_000,
        wiredBytes: 3_000,
        compressedBytes: 2_000,
        cachedBytes: 500,
        freeBytes: 300,
        swapUsedBytes: 3_000,
        pageSizeBytes: 4_096
    )

    let palette = MemorySnapshotPresentation.headerPalette(for: metrics)

    XCTAssertEqual(palette.statusSymbol, "flame.fill")
    XCTAssertEqual(palette.emphasis, .critical)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path macos-app --filter MemorySnapshotPresentationTests/testHeaderAccentReturnsCriticalPaletteForCriticalPressure`

Expected: FAIL until critical-state visual mapping exists.

- [ ] **Step 3: Write minimal implementation**

```swift
private var headerSection: some View {
    HStack(alignment: .top, spacing: 16) {
        VStack(alignment: .leading, spacing: 10) {
            headerTitleRow
            headerSummaryRow
        }

        Spacer(minLength: 16)

        VStack(alignment: .trailing, spacing: 8) {
            refreshPickerRow
            headerStatusBadge
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(cardBackground)
    .overlay(cardBorder)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path macos-app --filter MemorySnapshotPresentationTests`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotView.swift macos-app/Sources/MacBookOptimizationApp/Features/Dashboard/Views/MemorySnapshotPresentation.swift macos-app/Tests/MacBookOptimizationAppTests/MemorySnapshotPresentationTests.swift
git commit -m "feat: refresh memory snapshot visuals"
```
