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
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UIKit camera perspective modal"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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

    func testFullscreenDragCanCancelAndDismiss() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestReset", "YES", "-ScreenshotMode", "YES", "-ScreenshotSeed", "YES", "-ScreenshotLanguage", "en"]
        app.launch()
        let card = app.buttons["recordCard_DEBC1102-0000-0000-0000-000000000001"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let done = app.buttons["fullScreenCardDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 8))
        XCTAssertTrue(NSPredicate(format: "hittable == true").evaluate(with: done))
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        center.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: done)
        XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed)
        center.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        XCTAssertTrue(card.isHittable)
    }

    func testFullscreenEditPhotoChooserDismissesKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestReset", "YES", "-ScreenshotMode", "YES", "-ScreenshotSeed", "YES", "-ScreenshotLanguage", "en"]
        app.launch()
        let card = app.buttons["recordCard_DEBC1102-0000-0000-0000-000000000001"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let actions = app.buttons["fullScreenCardActions"]
        XCTAssertTrue(actions.waitForExistence(timeout: 8))
        actions.tap()
        app.buttons["Edit"].tap()
        let name = app.textFields["nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.buttons["addPhotoButton"].tap()
        XCTAssertTrue(app.buttons["Photo Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }

    func testFullscreenTransitionsWithContinuousMotion() {
        runMotionTransitions(withPhoto: false)
    }

    func testFullscreenTransitionsWithContinuousMotionAndPhoto() {
        runMotionTransitions(withPhoto: true)
    }

    func testFullscreenTransitionsWithLiveMaterialsAndPhoto() {
        runMotionTransitions(withPhoto: true, liveMaterials: true)
    }

    func testDevicePerformanceLogRecordsMovingTransitions() {
        runMotionTransitions(withPhoto: true, diagnostics: true)
    }
    func testListScrollsWithUnthrottledMotionAndPhoto() {
        runMotionScrolls(liveMaterials: false, unthrottled: true)
    }

    func testFullscreenTransitionsWithUnthrottledMotionAndPhoto() {
        runMotionTransitions(withPhoto: true, unthrottled: true)
    }

    func testListScrollsWithContinuousMotionAndPhoto() {
        runMotionScrolls(liveMaterials: false)
    }

    func testListScrollsWithPerformanceDiagnosticsAndPhoto() {
        runMotionScrolls(liveMaterials: false, diagnostics: true)
    }

    func testListScrollsWithLiveMaterialsAndContinuousMotionAndPhoto() {
        runMotionScrolls(liveMaterials: true)
    }

    private func runMotionScrolls(liveMaterials: Bool, unthrottled: Bool = false, diagnostics: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-ScreenshotMode", "YES", "-ScreenshotSeed", "YES", "-ScreenshotLanguage", "en",
                               "-MotionPerformanceHarness", "-MotionScrollHarness", "-MotionHarnessPhoto",
                               "-FaceScene.listEnabled", "YES", "-FaceScene.expandedEnabled", "YES", "-FaceScene.cameraEnabled", "NO"]
        if liveMaterials { app.launchArguments.append("-MotionLiveMaterials") }
        if unthrottled { app.launchArguments.append("-MotionHarnessUnthrottled") }
        if diagnostics { app.launchArguments.append("-PerformanceDiagnosticsRecord") }
        app.launch()
        Thread.sleep(forTimeInterval: 21)
        XCTAssertTrue(app.buttons["recordCard_DEBC1102-0000-0000-0000-000000000001"].exists)
        if diagnostics { prepareDiagnosticLog(app) }
    }

    func testPerformanceLogCanBePreparedFromSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["-ScreenshotMode", "YES", "-ScreenshotSeed", "YES", "-ScreenshotLanguage", "en", "-ScreenshotSceneSettings"]
        app.launch()
        let toggle = app.switches["recordPerformance"]
        for _ in 0..<8 {
            if toggle.exists && toggle.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        let prepare = app.buttons["preparePerformanceLog"]
        if !prepare.isHittable { app.swipeUp() }
        XCTAssertTrue(prepare.waitForExistence(timeout: 5))
        prepare.tap()
        let share = app.buttons["sharePerformanceLog"]
        if !share.isHittable { app.swipeUp() }
        XCTAssertTrue(share.waitForExistence(timeout: 5))
    }

    func testSettingsSuspendMovingCardsAndResume() {
        let app = XCUIApplication()
        app.launchArguments = ["-ScreenshotMode", "YES", "-ScreenshotSeed", "YES", "-ScreenshotLanguage", "en",
                               "-MotionPerformanceHarness", "-PerformanceDiagnosticsRecord",
                               "-FaceScene.listEnabled", "YES", "-FaceScene.expandedEnabled", "YES",
                               "-FaceScene.cameraEnabled", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        app.buttons["Settings"].tap()
        let scene = app.buttons["3D scene"]
        for _ in 0..<6 {
            if scene.exists && scene.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(scene.waitForExistence(timeout: 5))
        scene.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 3)
        app.swipeUp()
        app.swipeDown()
        app.buttons["Done"].tap()
        Thread.sleep(forTimeInterval: 2)
        app.buttons["Settings"].tap()
        for _ in 0..<6 {
            if scene.exists && scene.isHittable { break }
            app.swipeUp()
        }
        scene.tap()
        let prepare = app.buttons["preparePerformanceLog"]
        for _ in 0..<10 {
            if prepare.exists && prepare.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(prepare.waitForExistence(timeout: 5))
        prepare.tap()
        XCTAssertTrue(app.buttons["sharePerformanceLog"].waitForExistence(timeout: 5))
    }

    private func runMotionTransitions(withPhoto: Bool, diagnostics: Bool = false, liveMaterials: Bool = false, unthrottled: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-ScreenshotMode", "YES", "-ScreenshotSeed", "YES",
                               "-ScreenshotLanguage", "en", "-MotionPerformanceHarness",
                               "-FaceScene.listEnabled", "YES", "-FaceScene.expandedEnabled", "YES",
                               "-FaceScene.cameraEnabled", "NO"]
        if withPhoto { app.launchArguments.append("-MotionHarnessPhoto") }
        if liveMaterials { app.launchArguments.append("-MotionLiveMaterials") }
        if unthrottled { app.launchArguments.append("-MotionHarnessUnthrottled") }
        if diagnostics { app.launchArguments.append("-PerformanceDiagnosticsRecord") }
        app.launch()
        let card = app.buttons["recordCard_DEBC1102-0000-0000-0000-000000000001"]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.tap()
        // The app drives five actual zoom-in/out cycles itself. Do not perform
        // accessibility snapshots while animation frame timings are recorded.
        Thread.sleep(forTimeInterval: 25)
        XCTAssertTrue(app.buttons["fullScreenCardDone"].waitForNonExistence(timeout: 8))
        if diagnostics { prepareDiagnosticLog(app) }
    }

    private func prepareDiagnosticLog(_ app: XCUIApplication) {
        app.buttons["Settings"].tap()
        let scene = app.buttons["3D scene"]
        for _ in 0..<6 {
            if scene.exists && scene.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(scene.waitForExistence(timeout: 5))
        scene.tap()
        let prepare = app.buttons["preparePerformanceLog"]
        for _ in 0..<10 {
            if prepare.exists && prepare.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(prepare.waitForExistence(timeout: 5))
        prepare.tap()
        XCTAssertTrue(app.buttons["sharePerformanceLog"].waitForExistence(timeout: 8))
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
