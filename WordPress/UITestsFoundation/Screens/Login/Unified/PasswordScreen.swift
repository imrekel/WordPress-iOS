import ScreenObject
import XCTest

public class PasswordScreen: ScreenObject {

    public init(app: XCUIApplication = XCUIApplication()) throws {
        try super.init(
            // swiftlint:disable:next opening_brace
            expectedElementGetters: [ { $0.secureTextFields["Password"] } ],
            app: app,
            waitTimeout: 7
        )
    }

    public func proceedWith(password: String) throws -> LoginEpilogueScreen {
        _ = tryProceed(password: password)

        return try LoginEpilogueScreen()
    }

    public func tryProceed(password: String) -> PasswordScreen {
        // A hack to make tests pass for RtL languages.
        //
        // An unintended side effect of calling passwordTextField.tap() while testing a RtL language is that the
        // text field's secureTextEntry property gets set to 'false'. I suspect this happens because for RtL langagues,
        // the secure text entry toggle button is displayed in the tap area of the passwordTextField.
        //
        // As a result, tests fail with the following error:
        //
        // "No matches found for Descendants matching type SecureTextField from input"
        //
        // Calling passwordTextField.doubleTap() prevents tests from failing by ensuring that the text field's
        // secureTextEntry property remains 'true'.
        let passwordTextField = expectedElement
        passwordTextField.doubleTap()

        passwordTextField.typeText(password)
        let continueButton = app.buttons["Continue Button"]
        continueButton.tap()

        // The Simulator might as to save the password which, of course, we don't want to do
        if app.buttons["Save Password"].waitForExistence(timeout: 5) {
            // There should be no need to wait for this button to exist since it's part of the same
            // alert where "Save Password" is.
            app.buttons["Not Now"].tap()
        }

        return self
    }

    public func verifyLoginError() -> PasswordScreen {
        let errorLabel = app.cells["Password Error"]
        _ = errorLabel.waitForExistence(timeout: 2)

        XCTAssertTrue(errorLabel.exists)
        return self
    }

    public static func isLoaded() -> Bool {
        (try? PasswordScreen().isLoaded) ?? false
    }
}
