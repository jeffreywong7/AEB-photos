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

    override func tearDownWithError() throws {
        if let testRun, testRun.failureCount > 0 {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app.terminate()
    }

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
        let toggle = app.switches["camera.aebToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertEqual(app.buttons["camera.shutter"].value as? String, "Single photo")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(app.buttons["camera.shutter"].value as? String, "3 photos")
        tapPreview()
        XCTAssertFalse(toggle.exists)
    }

    func testExposureControlChangesToolbarValue() {
        app.buttons["camera.exposure"].tap()
        let exposure = app.sliders["Center exposure"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 3))
        exposure.adjust(toNormalizedSliderPosition: 0.75)
        assertExposure(exposure, positive: true)
        exposure.adjust(toNormalizedSliderPosition: 0.25)
        assertExposure(exposure, positive: false)
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

    func testPhotoReviewDoubleTapZoomAndReturn() {
        app.buttons["Review last capture"].tap()
        let image = app.descendants(matching: .any)["camera.review.image.1"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        XCTAssertEqual(image.value as? String, "Fit")
        image.doubleTap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Zoomed"), object: image)], timeout: 3), .completed)
        image.doubleTap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Fit"), object: image)], timeout: 3), .completed)
        app.buttons["camera.review.close"].tap()
        XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 3))
    }

    func testPhotoInformationUsesOriginalDimensions() {
        app.buttons["Review last capture"].tap()
        XCTAssertTrue(app.buttons["Photo information"].waitForExistence(timeout: 5))
        app.buttons["Photo information"].tap()
        XCTAssertTrue(app.staticTexts["Dimensions, 2400 × 3200"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Format, JPEG"].exists)
        app.buttons["Done"].tap()
        app.buttons["camera.review.close"].tap()
        XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 3))
    }

    func testPhotoReviewDragDownReturnsCamera() {
        app.buttons["Review last capture"].tap()
        XCTAssertTrue(app.buttons["camera.review.close"].waitForExistence(timeout: 5))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.01, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 3))
    }

    private func assertExposure(_ slider: XCUIElement, positive: Bool) {
        let value = slider.value as? String ?? ""
        XCTAssertEqual(app.buttons["camera.exposure"].value as? String, value)
        guard let ev = Float(value.replacingOccurrences(of: " EV", with: "")) else {
            XCTFail("Exposure must have a readable EV value, got \(value)")
            return
        }
        XCTAssertTrue((-2...2).contains(ev))
        if positive { XCTAssertGreaterThan(ev, 0) }
        else { XCTAssertLessThan(ev, 0) }
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
