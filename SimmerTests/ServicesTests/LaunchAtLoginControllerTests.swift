import XCTest

internal final class LaunchAtLoginControllerTests: XCTestCase {
  internal override init() {
    super.init()
  }

  func test_placeholderSkip() throws {
    let message = "LaunchAtLoginController behaviour covered via PatternListViewModelTests; "
      + "direct controller tests require ServiceManagement mocking not available in CI harness."
    throw XCTSkip(message)
  }
}
