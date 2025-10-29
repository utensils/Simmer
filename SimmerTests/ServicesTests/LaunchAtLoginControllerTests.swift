import XCTest

final class LaunchAtLoginControllerTests: XCTestCase {
  func test_placeholderSkip() throws {
    throw XCTSkip("LaunchAtLoginController behaviour covered via PatternListViewModelTests; direct controller tests require ServiceManagement mocking not available in CI harness.")
  }
}
