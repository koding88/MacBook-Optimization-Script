import XCTest
@testable import MacBookOptimizationApp

final class OptimizationCatalogTests: XCTestCase {
    func testCatalogContainsExpectedCategories() {
        let actions = OptimizationCatalog.actions()
        let categories = Set(actions.map(\.category))

        XCTAssertTrue(categories.contains(.system))
        XCTAssertTrue(categories.contains(.network))
        XCTAssertTrue(categories.contains(.storage))
        XCTAssertTrue(categories.contains(.performance))
        XCTAssertTrue(categories.contains(.maintenance))
        XCTAssertTrue(categories.contains(.monitoring))
    }

    func testCatalogActionIDsAreUnique() {
        let actions = OptimizationCatalog.actions()
        let ids = actions.map(\.id)

        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryActionHasLocalizedTitleAndDescription() {
        let actions = OptimizationCatalog.actions()
        let english = AppLocalizer(language: .english)
        let vietnamese = AppLocalizer(language: .vietnamese)

        for action in actions {
            XCTAssertNotEqual(english.string(action.titleKey), action.titleKey, "Missing English title for \(action.id)")
            XCTAssertNotEqual(english.string(action.descriptionKey), action.descriptionKey, "Missing English description for \(action.id)")
            XCTAssertNotEqual(vietnamese.string(action.titleKey), action.titleKey, "Missing Vietnamese title for \(action.id)")
            XCTAssertNotEqual(vietnamese.string(action.descriptionKey), action.descriptionKey, "Missing Vietnamese description for \(action.id)")
        }
    }
}
