import XCTest

/// Generates the App Store / TestFlight marketing screenshots.
///
/// Drive this from `Tools/generate-screenshots.sh`, which loops over the
/// supported languages and appearances and sets `SCREENSHOT_LANGUAGE` and
/// `SCREENSHOT_APPEARANCE`. Each test method captures one shot.
///
/// Don't run this class as part of the regular UI test suite — the shell
/// script invokes it explicitly via `-only-testing:`.
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Test methods

    func test_01_emptyState() {
        let app = launch(seeded: false)
        // The empty-state pill is wrapped in a Button (taps open the create
        // form); query by button id, not staticText.
        XCTAssertTrue(
            app.buttons["emptyStateTitle"].waitForExistence(timeout: 8),
            "Empty-state title never appeared"
        )
        // Hold a beat so any first-frame settle finishes.
        sleep(1)
        capture(app, name: "01-empty-state")
    }

    func test_02_listDistanceSorted() {
        let app = launch(seeded: true)
        waitForList(app)
        selectDistanceSort(app)
        sleep(1)
        capture(app, name: "02-list")
    }

    func test_03_listSortSheetOpen() {
        let app = launch(seeded: true)
        waitForList(app)
        app.buttons["sortButton"].tap()
        // Sheet animates in; give it a beat before the existence check so a
        // mid-animation snapshot doesn't read empty.
        sleep(1)
        XCTAssertTrue(
            app.buttons["sortOption_distance"].waitForExistence(timeout: 10),
            "Sort sheet never presented"
        )
        sleep(1)
        capture(app, name: "03-list-sort-open")
    }

    func test_04_detailMediumIris() {
        let app = launch(seeded: true)
        waitForList(app)
        // Iris's stable UUID from ScreenshotSeeder.
        let iris = app.buttons["recordCard_\(Self.irisRecordID)"]
        XCTAssertTrue(iris.waitForExistence(timeout: 5))
        iris.tap()
        // The tapped-card modal element may register as either an AXOther
        // (Group/Container) or an AXButton, depending on how SwiftUI resolves
        // the accessibility traits — check both.
        let modalCard = app.descendants(matching: .any).matching(identifier: "tappedCardModalCard").firstMatch
        XCTAssertTrue(
            modalCard.waitForExistence(timeout: 5),
            "Medium detail card never appeared"
        )
        sleep(1)
        capture(app, name: "04-detail-iris")
    }

    /// Stable UUID matching `ScreenshotSeeder` for the first record (Iris).
    private static let irisRecordID = "DEBC1102-0000-0000-0000-000000000001"

    func test_05_createStep1Name() {
        let app = launch(seeded: false)
        XCTAssertTrue(app.buttons["createRecordButton"].waitForExistence(timeout: 5))
        app.buttons["createRecordButton"].tap()

        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Felix")

        // Type a short association into the description field.
        let descField = app.textFields["descriptionField"]
        if descField.waitForExistence(timeout: 2) {
            descField.tap()
            descField.typeText("shared a cab from JFK")
        }
        // Dismiss the keyboard so it doesn't cover the form.
        app.tap()
        sleep(1)
        capture(app, name: "05-create-step1")
    }

    func test_06_createStep2Filled() {
        let app = launch(seeded: false)
        XCTAssertTrue(app.buttons["createRecordButton"].waitForExistence(timeout: 5))
        app.buttons["createRecordButton"].tap()

        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Felix")

        let descField = app.textFields["descriptionField"]
        if descField.waitForExistence(timeout: 2) {
            descField.tap()
            descField.typeText("shared a cab from JFK")
        }

        // Open the zodiac picker and pick one so the card paints a sign.
        let zodiacButton = app.buttons["addZodiacButton"]
        if zodiacButton.waitForExistence(timeout: 2) {
            zodiacButton.tap()
            let leoPicker = app.buttons["zodiacPickerButton_leo"]
            if leoPicker.waitForExistence(timeout: 3) {
                leoPicker.tap()
            }
        }
        app.tap()
        sleep(1)
        capture(app, name: "06-create-step2")
    }

    // MARK: Helpers

    private func waitForList(_ app: XCUIApplication) {
        // Wait for the first seeded record card by stable UUID — the seeder
        // runs in a .task so there's a tick between launch and rows being
        // visible.
        let firstCard = app.buttons["recordCard_\(Self.irisRecordID)"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10), "Seeded list never populated")
    }

    private func selectDistanceSort(_ app: XCUIApplication) {
        app.buttons["sortButton"].tap()
        // Sheet animates in; without this beat the existence check has been
        // observed to fire mid-transition and miss the row.
        sleep(1)
        let row = app.buttons["sortOption_distance"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Distance sort row not found")
        row.tap()
    }

    /// Saves the screenshot as an `XCTAttachment` named for the screen.
    /// The driver script (`Tools/generate-screenshots.sh`) is what knows the
    /// current device + appearance — it pulls the PNG out of the xcresult by
    /// matching the testIdentifier in `manifest.json` and writes it to the
    /// right `Screenshots/<device>/<appearance>/<screen>.png` path.
    ///
    /// We can't write directly to a host path because the test process runs
    /// inside the simulator's sandbox — `/tmp` from here is *the simulator's*
    /// /tmp, not the host's.
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch(seeded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-ScreenshotMode", "YES"]
        if seeded {
            args += ["-ScreenshotSeed", "YES"]
        }
        // The driver script forwards SCREENSHOT_APPEARANCE and
        // SCREENSHOT_LANGUAGE via the
        // `TEST_RUNNER_` prefix convention so xcodebuild propagates it into
        // the test runner's environment. We then push it on as a launch
        // argument to the app under test, where `RootScene` reads it via
        // `ScreenshotMode` and applies deterministic appearance + locale.
        if let appearance = ProcessInfo.processInfo.environment["SCREENSHOT_APPEARANCE"]?.lowercased(),
           appearance == "light" || appearance == "dark" {
            args += ["-AppearanceOverride", appearance]
        }
        if let language = ProcessInfo.processInfo.environment["SCREENSHOT_LANGUAGE"]?.lowercased(),
           language == "en" || language == "ru" || language == "uk" {
            args += ["-ScreenshotLanguage", language]
        }
        app.launchArguments = args
        app.launch()
        return app
    }
}
