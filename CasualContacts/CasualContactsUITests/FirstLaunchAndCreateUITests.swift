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

    func testCameraExplanationHasOneContinueAction() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestReset", "YES", "-ScreenshotMode", "YES", "-ScreenshotSeed", "YES", "-ScreenshotSceneSettings", "-ScreenshotCameraExplanation"]
        app.launch()
        XCTAssertTrue(app.buttons["Continue to camera permission"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Use gyro only"].exists)
        XCTAssertTrue(app.staticTexts["Camera is optional. Decline for gyro motion; change access in 3D scene."].exists)
    }

    func testCameraExplanationAndRecoveryAreLocalized() {
        for (language, title, action, recovery) in [
            ("en", "CAMERA PERSPECTIVE", "Continue to camera permission", "Enable camera in Settings"),
            ("ru", "ПЕРСПЕКТИВА С КАМЕРЫ", "Продолжить к запросу доступа к камере", "Разрешить камеру в настройках"),
            ("uk", "ПЕРСПЕКТИВА З КАМЕРИ", "Продовжити до запиту доступу до камери", "Дозволити камеру в параметрах")
        ] {
            let app = XCUIApplication()
            let base = ["-ScreenshotMode", "YES", "-ScreenshotSeed", "YES", "-ScreenshotSceneSettings", "-ScreenshotLanguage", language]
            app.launchArguments = base + ["-ScreenshotCameraExplanation"]
            app.launch()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[action].exists)
            app.terminate()
            app.launchArguments = base + ["-ScreenshotCameraDenied"]
            app.launch()
            XCTAssertTrue(app.buttons[recovery].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    func testDeniedCameraShowsSettingsRecovery() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestReset", "YES", "-ScreenshotMode", "YES", "-ScreenshotSeed", "YES", "-ScreenshotSceneSettings", "-ScreenshotCameraDenied"]
        app.launch()
        XCTAssertTrue(app.buttons["Enable camera in Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["Use camera for face perspective"].isEnabled)
        XCTAssertTrue(app.switches["Cards in the list"].isEnabled)
    }

    func testFirstSavedCardOffersCameraOnlyOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestReset", "YES", "-ScreenshotMode", "YES", "-FaceScene.cameraOfferSeen", "NO"]
        app.launch()
        for name in ["First", "Second"] {
            app.buttons["createRecordButton"].tap()
            let locationContinue = app.buttons["locationPrimerContinueButton"]
            if locationContinue.waitForExistence(timeout: 2) { locationContinue.tap() }
            let field = app.textFields["nameField"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(name)
            app.buttons["saveRecordButton"].firstMatch.tap()
            let continueButton = app.buttons["Continue to camera permission"]
            if name == "First" {
                XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
                continueButton.tap()
                let deny = app.alerts.buttons["Don’t Allow"]
                if deny.waitForExistence(timeout: 5) {
                    deny.tap()
                } else {
                    let systemDeny = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Don’t Allow"]
                    if systemDeny.waitForExistence(timeout: 2) { systemDeny.tap() }
                }
                XCTAssertTrue(continueButton.waitForNonExistence(timeout: 5))
            } else {
                XCTAssertFalse(continueButton.waitForExistence(timeout: 2))
            }
            XCTAssertTrue(app.buttons["createRecordButton"].waitForExistence(timeout: 3))
        }
        app.terminate()
        app.launchArguments = ["-ScreenshotMode", "YES"]
        app.launch()
        XCTAssertFalse(app.buttons["Continue to camera permission"].waitForExistence(timeout: 2))
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
    func testCardZoomsToFullScreenAndReturns() {
        let app = XCUIApplication()
        app.launchArguments = ["-ScreenshotMode", "YES", "-ScreenshotSeed", "YES"]
        app.launch()
        let card = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "recordCard_")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        let done = app.buttons["fullScreenCardDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(done.waitForExistence(timeout: 1))
    }

}
