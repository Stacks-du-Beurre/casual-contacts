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
        let emptyTitle = app.buttons["emptyStateTitle"]
        XCTAssertTrue(emptyTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(emptyTitle.label, "add the first person")
    }

    func testCreateRecordAppearsInList() {
        let app = launch()
        XCTAssertTrue(app.buttons["emptyStateTitle"].waitForExistence(timeout: 5))

        app.buttons["createRecordButton"].tap()

        let locationContinue = app.buttons["locationPrimerContinueButton"]
        if locationContinue.waitForExistence(timeout: 3) {
            locationContinue.tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allowLocation = springboard.buttons["Allow While Using App"]
            if allowLocation.waitForExistence(timeout: 3) {
                allowLocation.tap()
            }
        }

        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Jane")

        app.buttons["saveRecordButton"].firstMatch.tap()

        let janeRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "recordCard_")
        ).firstMatch
        XCTAssertTrue(janeRow.waitForExistence(timeout: 5))
        XCTAssertTrue(janeRow.label.contains("Jane"))
        XCTAssertFalse(nameField.exists)

        XCTAssertFalse(app.buttons["emptyStateTitle"].exists)
    }
}
