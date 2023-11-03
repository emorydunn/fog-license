//
//  LicenseCodeTests.swift
//  
//
//  Created by Emory Dunn on 10/30/23.
//

import XCTest
@testable import SharedModels
import ByteKit

struct TestSeed: CodeSeed {

	let magicByteRange = UInt8.min...0x42

	var magicByte: UInt8 {
		0x42
	}

	var standardByte: UInt8 {
		0x69
	}
}

final class LicenseCodeTests: XCTestCase {

	override class func setUp() {
		LicenseCode.seed = TestSeed()
	}

	func testCode() {
		let code = LicenseCode(appID: 6)

		XCTAssertEqual(code.bytes, [6, 105, 66, 105])
		XCTAssertEqual(code.number, 107561577)
		XCTAssertEqual(code.id, 107561577)
	}

	func testValidity() {
		let code = LicenseCode(appID: 6)

		XCTAssertTrue(code.isValid(for: 6))
		XCTAssertFalse(code.isValid(for: 8))

	}

	func testLiteralInit() {
		let code: LicenseCode = 107561577

		XCTAssertEqual(code, LicenseCode(appID: 6))
	}

	func testByteInit() {
		let code = LicenseCode(6, 105, 66, 105)

		XCTAssertNotNil(code)
	}

	func testInvalidByteInit() {
		let code = LicenseCode(6, 105, 66)

		XCTAssertNil(code)
	}

	func testNumber() {
		let code = LicenseCode(appID: 6)

		XCTAssertEqual(code, LicenseCode(code.number))
	}

	func testCoding() throws {
		let code = LicenseCode(appID: 6)
		let data = try JSONEncoder().encode(code)
		let json = String(decoding: data, as: UTF8.self)

		XCTAssertEqual(json, "107561577")

		let newCode = try JSONDecoder().decode(LicenseCode.self, from: data)

		XCTAssertEqual(code, newCode)
	}

	func testFormatting() {
		let code = LicenseCode(appID: 6)

		XCTAssertEqual(code.formatted(.bytes), "6 105 66 105")

	}

}
