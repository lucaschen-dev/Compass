import XCTest

/// Tests the actual SwiftUI surface, rather than Flutter's retained fallback UI.
final class CompassNativeUITests: XCTestCase {
  func testNativeCampusFlow() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    let demo = app.buttons["demo-entry"]
    XCTAssertTrue(demo.waitForExistence(timeout: 20))
    demo.nativeTap()
    #if os(iOS)
      XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
      app.tabBars.buttons["Chat"].nativeTap()
    #else
      XCTAssertTrue(app.outlines.firstMatch.waitForExistence(timeout: 10))
      app.outlines.staticTexts["Chat"].firstMatch.click()
    #endif
    let maya = app.staticTexts["Maya Taylor"].firstMatch
    XCTAssertTrue(maya.waitForExistence(timeout: 10))
    #if os(iOS)
      maya.nativeTap()
    #else
      maya.click()
    #endif
    let message = app.descendants(matching: .any).matching(identifier: "message-input").firstMatch
    XCTAssertTrue(message.waitForExistence(timeout: 10))
    #if os(iOS)
      message.nativeTap()
    #else
      message.click()
    #endif
    message.typeText("Native UI verification message")
    app.buttons["Send message"].firstMatch.nativeTap()
    XCTAssertTrue(
      app.staticTexts["Native UI verification message"].firstMatch.waitForExistence(timeout: 10))
    #if os(iOS)
      app.navigationBars.buttons.element(boundBy: 0).nativeTap()
      app.tabBars.buttons["Home"].nativeTap()
    #else
      app.outlines.staticTexts["Home"].firstMatch.click()
    #endif
    let newPost = app.buttons["New post"].firstMatch
    XCTAssertTrue(newPost.waitForExistence(timeout: 10))
    newPost.nativeTap()
    let title = app.descendants(matching: .any).matching(identifier: "post-title").firstMatch
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    title.nativeTap()
    title.typeText("Native SwiftUI post")
    let body = app.descendants(matching: .any).matching(identifier: "post-body").firstMatch
    body.nativeTap()
    body.typeText("This draft is saved by Flutter and displayed with Apple controls.")
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Native post composer"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.buttons["publish-post"].nativeTap()
    let ok = app.alerts.buttons["OK"].firstMatch
    if ok.waitForExistence(timeout: 8) { ok.nativeTap() }
    XCTAssertTrue(app.staticTexts["Native SwiftUI post"].firstMatch.waitForExistence(timeout: 10))
    let home = XCTAttachment(screenshot: app.screenshot())
    home.name = "Native campus home"
    home.lifetime = .keepAlways
    add(home)
  }
}

extension XCUIElement {
  func nativeTap() {
    #if os(macOS)
      click()
    #else
      tap()
    #endif
  }
}
