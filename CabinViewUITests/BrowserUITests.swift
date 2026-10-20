import XCTest

@MainActor
final class BrowserUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        await MainActor.run {
            continueAfterFailure = false
            launchBrowser()
        }
    }

    func testNavigationIsVisibleOnStartPage() {
        XCTAssertFalse(app.otherElements["launchSplash"].exists)
        XCTAssertFalse(app.staticTexts["Website sessions saved on this iPhone"].exists)
        XCTAssertTrue(app.textFields["browserSearch"].exists)
        XCTAssertTrue(app.buttons["browserBack"].exists)
        XCTAssertFalse(app.buttons["browserBack"].isEnabled)
        XCTAssertFalse(app.buttons["browserForward"].isEnabled)
        XCTAssertFalse(app.buttons["sharePage"].isEnabled)
        XCTAssertTrue(app.buttons["browserMore"].isEnabled)
        attachScreenshot("Start page")
    }

    func testSearchCanBeClearedAndCancelled() {
        let field = app.textFields["browserSearch"]
        field.tap()
        field.typeText("a search to edit")
        app.buttons["clearSearch"].tap()
        XCTAssertFalse(app.buttons["submitSearch"].isEnabled)
        app.buttons["cancelSearch"].tap()
        XCTAssertTrue(app.buttons["browserBack"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    func testUnsafeAddressShowsRecoverableError() {
        enter("javascript:alert(1)")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Enter a search or a valid website address")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["Dismiss error"].tap()
        XCTAssertFalse(app.otherElements["browserError"].exists)
        XCTAssertTrue(app.textFields["browserSearch"].isEnabled)
    }

    func testWebsiteNavigationBackForwardAndHome() {
        // This smoke test intentionally checks real HTTPS loading; it needs internet access.
        enter("https://example.com/?cabinview=one")
        let heading = app.webViews.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Example Domain")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 25))
        enter("https://example.com/?cabinview=two")
        waitForAddress(containing: "cabinview=two")
        XCTAssertTrue(app.buttons["browserBack"].isEnabled)
        app.buttons["browserBack"].tap()
        waitForAddress(containing: "cabinview=one")
        app.buttons["browserForward"].tap()
        waitForAddress(containing: "cabinview=two")
        app.buttons["browserHome"].tap()
        XCTAssertTrue(app.buttons["resumeBrowsing"].waitForExistence(timeout: 3))
        app.buttons["browserBack"].tap()
        waitForAddress(containing: "cabinview=two")
        XCTAssertTrue(app.buttons["sharePage"].isEnabled)
        attachScreenshot("Browsing with visible navigation")
    }

    func testClearWebsiteDataNeedsConfirmation() {
        app.buttons["browserMore"].tap()
        app.buttons["Clear website data"].tap()
        XCTAssertTrue(app.staticTexts["Clear all website sessions?"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.textFields["browserSearch"].isEnabled)
    }

    func testPrivacyPolicyLinkIsDisabledUntilConfigured() {
        app.buttons["browserMore"].tap()
        let privacyPolicy = app.buttons["Privacy policy"]
        XCTAssertTrue(privacyPolicy.waitForExistence(timeout: 3))
        XCTAssertFalse(privacyPolicy.isEnabled)
        XCTAssertFalse(app.staticTexts["CabinView privacy policy"].exists)
    }

    func testLargerTextKeepsControlsAccessible() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchBrowser()
        XCTAssertTrue(app.textFields["browserSearch"].isHittable)
        XCTAssertTrue(app.buttons["browserMore"].isHittable)
        app.textFields["browserSearch"].tap()
        XCTAssertTrue(app.buttons["cancelSearch"].isHittable)
        app.buttons["cancelSearch"].tap()
        attachScreenshot("Larger text")
    }

    private func launchBrowser() {
        app.launch()
        XCTAssertTrue(app.textFields["browserSearch"].waitForExistence(timeout: 5))
    }

    private func enter(_ value: String) {
        app.textFields["browserSearch"].tap()
        if app.buttons["clearSearch"].exists { app.buttons["clearSearch"].tap() }
        app.textFields["browserSearch"].typeText(value)
        app.buttons["submitSearch"].tap()
    }

    private func waitForAddress(containing value: String) {
        let matches = NSPredicate(format: "value CONTAINS %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: matches, object: app.textFields["browserSearch"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 15), .completed)
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Reload"), object: app.buttons["reloadPage"])
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 20), .completed)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
