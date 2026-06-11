import XCTest

final class FitcountableUITests: XCTestCase {
    @MainActor
    func testOnboardingSignInAndEnterDashboard() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FITCOUNTABLE_RESET_STATE"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["Say what happened. We log it."].waitForExistence(timeout: 6))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["What's the main goal?"].waitForExistence(timeout: 3))
        app.staticTexts["Build muscle"].tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Build the weekly target."].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Nutrition tracking style"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Accountability mode"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Save your plan with Apple."].waitForExistence(timeout: 3))
        let devSignIn = app.buttons["Sign in with developer test account"]
        XCTAssertTrue(devSignIn.waitForExistence(timeout: 3))
        devSignIn.tap()

        XCTAssertTrue(app.staticTexts["Your starting plan is ready."].waitForExistence(timeout: 20))
        app.buttons["Enter Fitcountable"].tap()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["DAILY FUEL"].waitForExistence(timeout: 4))
    }
}
