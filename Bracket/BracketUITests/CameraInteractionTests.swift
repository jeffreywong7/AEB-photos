import XCTest

final class CameraInteractionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--camera-ui-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 10))
        // A fresh simulator can present a setup notification over the toolbar.
        let header = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        header.press(forDuration: 0.01, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01)))
    }

    override func tearDownWithError() throws { app.terminate() }

    func testMainCameraCyclesFocalLengths() {
        let main = app.buttons["camera.zoom.1"]
        main.tap()
        XCTAssertTrue(app.staticTexts["28"].exists)
        main.tap()
        XCTAssertTrue(app.staticTexts["35"].exists)
        main.tap()
        XCTAssertTrue(app.staticTexts["24"].exists)
    }

    func testLongPressOpensWheelAndPreviewTapClosesIt() {
        app.buttons["camera.zoom.1"].press(forDuration: 0.5)
        let wheel = app.descendants(matching: .any)["camera.zoomWheel"]
        XCTAssertTrue(wheel.waitForExistence(timeout: 3))
        tapPreview()
        XCTAssertFalse(wheel.exists)
        XCTAssertTrue(app.buttons["camera.zoom.1"].exists)
    }

    func testAEBToggleChangesShutterCaptureMode() {
        app.buttons["camera.controls"].tap()
        let toggle = app.switches["AEB"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.tap()
        XCTAssertEqual(app.buttons["camera.shutter"].value as? String, "Single photo")
        toggle.tap()
        XCTAssertEqual(app.buttons["camera.shutter"].value as? String, "3 photos")
        tapPreview()
        XCTAssertFalse(toggle.exists)
    }

    func testExposureControlChangesToolbarValue() {
        app.buttons["camera.exposure"].tap()
        let exposure = app.sliders["Center exposure"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 3))
        exposure.adjust(toNormalizedSliderPosition: 0.75)
        XCTAssertEqual(app.buttons["camera.exposure"].value as? String, "+1.0 EV")
        tapPreview()
        XCTAssertFalse(exposure.exists)
    }

    func testTimerCanBeCancelledAndRestarted() {
        selectThreeSecondTimer()
        app.buttons["camera.shutter"].tap()
        XCTAssertTrue(app.buttons["Cancel timer"].waitForExistence(timeout: 2))
        app.buttons["Cancel timer"].tap()
        XCTAssertFalse(app.buttons["Cancel timer"].exists)
        app.buttons["camera.shutter"].tap()
        XCTAssertTrue(app.buttons["Cancel timer"].waitForExistence(timeout: 2))
        app.buttons["Cancel timer"].tap()
        XCTAssertFalse(app.buttons["Cancel timer"].exists)
    }

    func testBackgroundingCancelsTimer() {
        selectThreeSecondTimer()
        app.buttons["camera.shutter"].tap()
        XCTAssertTrue(app.buttons["Cancel timer"].waitForExistence(timeout: 2))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Cancel timer"].exists)
        XCTAssertTrue(app.buttons["camera.shutter"].isEnabled)
    }

    private func selectThreeSecondTimer() {
        app.buttons["camera.controls"].tap()
        app.buttons["Timer"].tap()
        app.buttons["3 second timer"].tap()
        tapPreview()
    }

    private func tapPreview() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
    }
}
