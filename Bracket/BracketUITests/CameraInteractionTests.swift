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

    func testHoldLocksFocusAndExposureThroughAdjustmentAndCapture() {
        holdPreview()
        let lock = app.staticTexts["camera.focusLock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 3))
        XCTAssertEqual(lock.label, "AE/AF LOCK")
        XCTAssertTrue(app.buttons["camera.shutter"].isEnabled)
        app.buttons["camera.exposure"].tap()
        let exposure = app.sliders["Center exposure"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 3))
        exposure.adjust(toNormalizedSliderPosition: 0.75)
        assertExposure(exposure, positive: true)
        app.buttons["camera.controls"].tap()
        XCTAssertEqual(lock.label, "AE/AF LOCK")
        app.buttons["camera.shutter"].tap()
        let review = app.buttons["Review last capture"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: review)], timeout: 10), .completed)
        XCTAssertEqual(lock.label, "AE/AF LOCK")
        tapPreview()
        XCTAssertFalse(lock.exists)
    }

    func testBackgroundingClearsFocusLock() {
        holdPreview()
        XCTAssertTrue(app.staticTexts["camera.focusLock"].waitForExistence(timeout: 3))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["camera.focusLock"].exists)
        XCTAssertTrue(app.buttons["camera.shutter"].isEnabled)
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
        XCTAssertFalse(app.staticTexts["Unknown date"].exists)
        app.buttons["Photo information"].tap()
        XCTAssertTrue(app.staticTexts["Dimensions, 2400 × 3200"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Format, JPEG"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Captured,'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Captured, Unknown"].exists)
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

    func testAspectChoiceChangesCapturedJPEGDimensions() {
        for (aspect, dimensions) in [("1:1", "2400 × 2400"), ("16:9", "1800 × 3200")] {
            app.buttons["camera.controls"].tap()
            app.buttons["Aspect"].tap()
            app.buttons["camera.aspect.\(aspect)"].tap()
            tapPreview()
            app.buttons["camera.shutter"].tap()
            let review = app.buttons["Review last capture"]
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: review)], timeout: 10), .completed)
            review.tap()
            XCTAssertTrue(app.buttons["Photo information"].waitForExistence(timeout: 5))
            app.buttons["Photo information"].tap()
            XCTAssertTrue(app.staticTexts["Dimensions, \(dimensions)"].waitForExistence(timeout: 3))
            app.buttons["Done"].tap()
            app.buttons["camera.review.close"].tap()
        }
    }

    func testLastBracketSurvivesAppRelaunch() {
        app.terminate()
        app.launchArguments += ["--camera-ui-store", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 5))
        app.buttons["camera.controls"].tap()
        app.buttons["Aspect"].tap()
        app.buttons["camera.aspect.1:1"].tap()
        tapPreview()
        app.buttons["camera.shutter"].tap()
        let review = app.buttons["Review last capture"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: review)], timeout: 10), .completed)
        app.terminate()
        app.launchArguments += ["--camera-ui-delay-restoration"]
        app.launch()
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        assertReviewWaitsForRestoration(review)
        review.tap()
        XCTAssertTrue(app.buttons["Photo information"].waitForExistence(timeout: 5))
        app.buttons["Photo information"].tap()
        XCTAssertTrue(app.staticTexts["Dimensions, 2400 × 2400"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["View photo 3 of 3"].exists)
    }

    func testPhotoLibraryOpensPNGWithoutJPEGConversion() {
        app.buttons["Review last capture"].tap()
        XCTAssertTrue(app.buttons["Browse photo library"].waitForExistence(timeout: 5))
        app.buttons["Browse photo library"].tap()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        let pickerScreenshot = XCTAttachment(screenshot: app.screenshot())
        pickerScreenshot.name = "System photo library"
        pickerScreenshot.lifetime = .keepAlways
        add(pickerScreenshot)
        let pickerHierarchy = XCTAttachment(string: app.debugDescription)
        pickerHierarchy.name = "System photo library accessibility"
        pickerHierarchy.lifetime = .keepAlways
        add(pickerHierarchy)
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH 'Screenshot,'")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertFalse(photo.frame.isEmpty)
        XCTAssertTrue(app.frame.contains(photo.frame))
        // The system grid reports image bounds but no XCTest hit point.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: cancel)], timeout: 10), .completed)
        app.buttons["Photo information"].tap()
        XCTAssertTrue(app.staticTexts["Format, PNG"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Dimensions, 1179 × 2556"].exists)
    }

    func testUndatedPhotoReviewShowsUnknownCaptureDate() {
        app.terminate()
        app.launchArguments += ["--camera-ui-state", "undated"]
        app.launch()
        XCTAssertTrue(app.buttons["Review last capture"].waitForExistence(timeout: 5))
        app.buttons["Review last capture"].tap()
        XCTAssertTrue(app.staticTexts["Unknown date"].waitForExistence(timeout: 5))
        app.buttons["Photo information"].tap()
        XCTAssertTrue(app.staticTexts["Captured, Unknown"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Format, JPEG"].exists)
        app.buttons["Done"].tap()
        app.buttons["camera.review.close"].tap()
        XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 5))
    }

    func testEmptyCaptureReviewCanCancelLibraryAndReturnToCamera() {
        app.terminate()
        app.launchArguments += ["--camera-ui-state", "empty", "--camera-ui-store", UUID().uuidString, "--camera-ui-delay-restoration"]
        app.launch()
        let review = app.buttons["Review last capture"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        assertReviewWaitsForRestoration(review)
        review.tap()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["camera.shutter"].isEnabled)
    }

    func testFailedRestorationStillAllowsLibraryReview() {
        app.terminate()
        app.launchArguments += ["--camera-ui-state", "restore-error", "--camera-ui-delay-restoration"]
        app.launch()
        let review = app.buttons["Review last capture"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        assertReviewWaitsForRestoration(review)
        review.tap()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["camera.shutter"].isEnabled)
    }

    private func assertReviewWaitsForRestoration(_ review: XCUIElement) {
        XCTAssertFalse(review.isEnabled)
        review.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["Browse photo library"].exists)
        XCTAssertFalse(app.buttons["Cancel"].exists)
        XCTAssertTrue(app.buttons["camera.shutter"].exists)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: review)], timeout: 20), .completed)
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

    private func holdPreview() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).press(forDuration: 0.8)
    }
}
