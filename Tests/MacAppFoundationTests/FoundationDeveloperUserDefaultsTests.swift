#if DEBUG
import Foundation
import XCTest
@testable import MacAppFoundation

@MainActor
final class FoundationDeveloperUserDefaultsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "FoundationDeveloperUserDefaultsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testModelShowsStoredAndEffectiveValues() {
        defaults.register(defaults: [
            "registered.flag": true,
        ])
        defaults.set("stored", forKey: "stored.string")

        let model = FoundationDeveloperUserDefaultsModel(
            defaults: defaults,
            domainName: suiteName
        )

        let registered = model.rows.first { $0.key == "registered.flag" }
        XCTAssertEqual(registered?.type, .bool)
        XCTAssertEqual(registered?.displayValue, "true")
        XCTAssertEqual(registered?.isPersistent, false)

        let stored = model.rows.first { $0.key == "stored.string" }
        XCTAssertEqual(stored?.type, .string)
        XCTAssertEqual(stored?.displayValue, "stored")
        XCTAssertEqual(stored?.isPersistent, true)
    }

    func testSettingEffectiveValueCreatesPersistentOverrideAndRemovingRevealsFallback() {
        defaults.register(defaults: [
            "feature.enabled": false,
        ])

        let model = FoundationDeveloperUserDefaultsModel(
            defaults: defaults,
            domainName: suiteName
        )

        model.set(true, forKey: "feature.enabled")

        var row = model.rows.first { $0.key == "feature.enabled" }
        XCTAssertEqual(row?.displayValue, "true")
        XCTAssertEqual(row?.isPersistent, true)
        XCTAssertEqual(defaults.bool(forKey: "feature.enabled"), true)

        model.removeValue(forKey: "feature.enabled")

        row = model.rows.first { $0.key == "feature.enabled" }
        XCTAssertEqual(row?.displayValue, "false")
        XCTAssertEqual(row?.isPersistent, false)
        XCTAssertEqual(defaults.bool(forKey: "feature.enabled"), false)
    }

    func testResetPersistentDomainPreservesRegisteredFallbacks() {
        defaults.register(defaults: [
            "registered.value": "fallback",
        ])
        defaults.set(42, forKey: "stored.number")

        let model = FoundationDeveloperUserDefaultsModel(
            defaults: defaults,
            domainName: suiteName
        )

        model.resetPersistentDomain()

        XCTAssertNil(model.rows.first { $0.key == "stored.number" })

        let registered = model.rows.first { $0.key == "registered.value" }
        XCTAssertEqual(registered?.displayValue, "fallback")
        XCTAssertEqual(registered?.isPersistent, false)
    }

    func testCodecRecognizesCommonUserDefaultsTypes() {
        XCTAssertEqual(
            FoundationDeveloperUserDefaultsCodec.valueType(for: true),
            .bool
        )
        XCTAssertEqual(
            FoundationDeveloperUserDefaultsCodec.valueType(for: 42),
            .integer
        )
        XCTAssertEqual(
            FoundationDeveloperUserDefaultsCodec.valueType(for: 1.5),
            .double
        )
        XCTAssertEqual(
            FoundationDeveloperUserDefaultsCodec.valueType(for: "hello"),
            .string
        )
        XCTAssertEqual(
            FoundationDeveloperUserDefaultsCodec.valueType(for: Date()),
            .date
        )
        XCTAssertEqual(
            FoundationDeveloperUserDefaultsCodec.valueType(for: Data([1, 2, 3])),
            .data
        )
        XCTAssertEqual(
            FoundationDeveloperUserDefaultsCodec.valueType(for: ["one", "two"]),
            .array
        )
        XCTAssertEqual(
            FoundationDeveloperUserDefaultsCodec.valueType(for: ["key": "value"]),
            .dictionary
        )
    }

    func testComplexPropertyListRoundTrip() throws {
        let array: [Any] = [
            "value",
            3,
            true,
            Data([1, 2]),
        ]

        let text = try XCTUnwrap(
            FoundationDeveloperUserDefaultsCodec.propertyListText(array)
        )
        let decoded = try FoundationDeveloperUserDefaultsCodec.propertyListValue(
            from: text,
            expectedType: .array
        )
        let decodedArray = try XCTUnwrap(decoded as? [Any])

        XCTAssertEqual(decodedArray.count, 4)
        XCTAssertEqual(decodedArray[0] as? String, "value")
        XCTAssertEqual((decodedArray[1] as? NSNumber)?.intValue, 3)
        XCTAssertEqual((decodedArray[2] as? NSNumber)?.boolValue, true)
        XCTAssertEqual(decodedArray[3] as? Data, Data([1, 2]))
    }
}
#endif
