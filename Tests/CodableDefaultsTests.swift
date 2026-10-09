import XCTest
@testable import TimeRewind

final class CodableDefaultsTests: XCTestCase {
    func testMissingFieldsUseDefaults() throws {
        let json = Data("{\"uses24Hour\": false}".utf8)
        let decoded = try JSONDecoder().decode(ClockFormatOptions.self, from: json)
        XCTAssertFalse(decoded.uses24Hour)
        XCTAssertTrue(decoded.leadingZeroHour)
    }

    func testWrongTypeFallsBackToDefault() throws {
        let json = Data("{\"format\": 42, \"capitalizeFirstLetter\": true}".utf8)
        let decoded = try JSONDecoder().decode(DateFormatOptions.self, from: json)
        XCTAssertEqual(decoded.format, TimeEngine.defaultDateFormat)
        XCTAssertTrue(decoded.capitalizeFirstLetter)
        XCTAssertEqual(decoded.localeIdentifier, "pt_BR")
    }

    func testRoundTrip() throws {
        let original = DateFormatOptions(format: "d/MM", localeIdentifier: "pt_BR", capitalizeFirstLetter: true)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(DateFormatOptions.self, from: data), original)
    }

    func testInputModeIsCodable() throws {
        let data = try JSONEncoder().encode([SecretInputMode.twoStepGrid])
        XCTAssertEqual(try JSONDecoder().decode([SecretInputMode].self, from: data), [.twoStepGrid])
    }
}
