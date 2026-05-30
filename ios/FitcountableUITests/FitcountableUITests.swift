import XCTest

final class FitcountableUITests: XCTestCase {
    func testOnboardingDashboardFoodAndAccountabilityPaths() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FITCOUNTABLE_RESET_STATE"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["Fitcountable"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Log workouts and meals by saying what happened."].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Start with Sign in with Apple."].waitForExistence(timeout: 2))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["What's the main goal?"].waitForExistence(timeout: 2))
        app.staticTexts["Build muscle"].tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Build the weekly target."].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Strength-first routine"].exists)
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Nutrition tracking style"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Calories: 2450"].exists)
        app.buttons["High protein"].tap()
        XCTAssertTrue(app.staticTexts["Protein: 205g"].waitForExistence(timeout: 2))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Accountability mode"].waitForExistence(timeout: 2))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Your starting plan is ready."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Your starting plan is ready."].exists)
        app.buttons["Enter Fitcountable"].tap()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Parsing command..."].exists)

        app.buttons["Log Food"].tap()
        XCTAssertTrue(app.staticTexts["Food and macros"].waitForExistence(timeout: 2))

        app.buttons["Social"].tap()
        XCTAssertTrue(app.staticTexts["Accountability mode"].waitForExistence(timeout: 2))

        app.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["Fitcountable Premium"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["More AI command capacity"].exists)
    }
}
