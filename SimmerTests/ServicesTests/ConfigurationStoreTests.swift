//
//  ConfigurationStoreTests.swift
//  SimmerTests
//

import XCTest
@testable import Simmer

@MainActor
internal final class ConfigurationStoreTests: XCTestCase {
  internal override init() {
    super.init()
  }

  private var suiteName: String!
  private var userDefaults: UserDefaults!
  private var store: ConfigurationStore!

  override func setUp() {
    super.setUp()
    suiteName = "io.utensils.SimmerTests.ConfigurationStoreTests"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create isolated UserDefaults suite")
      return
    }
    defaults.removePersistentDomain(forName: suiteName)
    userDefaults = defaults
    store = ConfigurationStore(userDefaults: defaults)
  }

  override func tearDown() {
    if let defaults = userDefaults, let suite = suiteName {
      defaults.removePersistentDomain(forName: suite)
    }
    userDefaults = nil
    suiteName = nil
    store = nil
    super.tearDown()
  }

  func test_loadPatterns_whenNothingPersisted_returnsEmptyCollection() {
    XCTAssertTrue(store.loadPatterns().isEmpty)
  }

  func test_savePatterns_whenCalled_persistsPatterns() throws {
    let pattern = makePattern(name: "Errors")
    try store.savePatterns([pattern])

    let loaded = store.loadPatterns()
    XCTAssertEqual(loaded, [pattern])
  }

  func test_updatePattern_whenPatternExists_replacesStoredValue() throws {
    var pattern = makePattern(name: "Queue Monitor")
    try store.savePatterns([pattern])

    pattern.name = "Updated Queue Monitor"
    try store.updatePattern(pattern)

    let loaded = store.loadPatterns()
    XCTAssertEqual(loaded.first?.name, "Updated Queue Monitor")
  }

  func test_updatePattern_whenPatternMissing_throwsPatternNotFound() throws {
    let missing = makePattern(name: "Missing")
    XCTAssertThrowsError(try store.updatePattern(missing)) { error in
      XCTAssertEqual(error as? ConfigurationStoreError, .patternNotFound)
    }
  }

  func test_deletePattern_whenPatternExists_removesItFromStorage() throws {
    let p1 = makePattern(name: "One")
    let p2 = makePattern(name: "Two")
    try store.savePatterns([p1, p2])

    try store.deletePattern(id: p1.id)
    let loaded = store.loadPatterns()
    XCTAssertEqual(loaded, [p2])
  }

  func test_deletePattern_whenPatternMissing_throwsPatternNotFound() {
    XCTAssertThrowsError(try store.deletePattern(id: UUID())) { error in
      XCTAssertEqual(error as? ConfigurationStoreError, .patternNotFound)
    }
  }

  func test_loadPatterns_whenCorruptDataFound_resetsStorage() throws {
    userDefaults.set("invalid", forKey: "patterns")

    let loaded = store.loadPatterns()
    XCTAssertTrue(loaded.isEmpty)
    XCTAssertNil(userDefaults.data(forKey: "patterns"))
  }

  func test_savePatterns_whenEncoderFails_throwsEncodingFailed() {
    let store = ConfigurationStore(
      userDefaults: userDefaults,
      encoder: ThrowingJSONEncoder(),
      decoder: JSONDecoder()
    )

    XCTAssertThrowsError(try store.savePatterns([makePattern(name: "Boom")])) { error in
      XCTAssertEqual(error as? ConfigurationStoreError, .encodingFailed)
    }
  }

  // MARK: - Helpers

  private func makePattern(name: String) -> LogPattern {
    LogPattern(
      name: name,
      regex: "error",
      logPath: "/tmp/test.log",
      color: CodableColor(red: 1, green: 0, blue: 0),
      animationStyle: .glow,
      enabled: true
    )
  }
}

private final class ThrowingJSONEncoder: JSONEncoder {
  override func encode<T>(_ value: T) throws -> Data where T: Encodable {
    throw EncodingError.invalidValue(
      value,
      .init(codingPath: [], debugDescription: "forced failure")
    )
  }
}
