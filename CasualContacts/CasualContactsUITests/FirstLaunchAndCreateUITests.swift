import XCTest

final class FirstLaunchAndCreateUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestReset", "YES"]
        app.launch()
        return app
    }

    func testFirstLaunchShowsEmptyState() {
        let app = launch()
        let emptyTitle = app.staticTexts["emptyStateTitle"]
        XCTAssertTrue(emptyTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(emptyTitle.label, "No one here yet")
    }

    func testCreateRecordAppearsInList() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["emptyStateTitle"].waitForExistence(timeout: 5))

        app.buttons["createRecordButton"].tap()

        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Jane")

        app.buttons["saveRecordButton"].tap()

        let janeRow = app.otherElements.containing(.any, identifier: "Jane").firstMatch
        XCTAssertTrue(janeRow.waitForExistence(timeout: 5))

        XCTAssertFalse(app.staticTexts["emptyStateTitle"].exists)
    }
}
