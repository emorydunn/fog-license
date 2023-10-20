//
//  LicenseCode.swift
//  
//
//  Created by Emory Dunn on 10/16/23.
//

import Foundation

/// A 24-bit license code.
///
/// A code is made up of three little endian bytes:
///
/// 0. The App ID
/// 1. Random 8-bit number
/// 2. Random 8-bit number within a clamped range
/// 3. Random 8-bit number (unused)
///
/// Byte 2 is clamped to a set range to act as magic number for quickly verifying the code is valid and not just a random guess.
///
/// - Note: This should result in 17,152 possible license codes per application, but if more are
/// 	needed the _Secret Fourth Byte_ can be enabled, utilizing the full 32-bit backing for 4,390,912 codes.
struct LicenseCode: Codable, ExpressibleByIntegerLiteral {

	static var codeRange = 0..<3
	static var magicByteRange = UInt8.min..<0x42

	let number: UInt32

	init(_ code: UInt32) {
		self.number = code
	}

	init(integerLiteral value: IntegerLiteralType) {
		self.number = UInt32(value)
	}

	init(_ bytes: UInt8...) {
		self.number = UInt32(from: bytes, range: LicenseCode.codeRange)
	}

	init(appID: UInt8) {
		let bytes = [
			UInt8.random(in: UInt8.min..<UInt8.max), // Secret extra byte in case I run out of codes
			UInt8.random(in: LicenseCode.magicByteRange),
			UInt8.random(in: UInt8.min..<UInt8.max),
			appID,
		]

		self.number = UInt32(from: bytes, range: LicenseCode.codeRange)
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.number = try container.decode(UInt32.self)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(self.number)
	}

	/// Test whether the license code is matches the specified App ID.
	/// - Parameter appID: The identifier of an application.
	/// - Returns: Whether the license code is valid.
	func isValid(for appID: UInt8) -> Bool {
		let bytes = number.bytes(littleEndian: true, startingAt: 1)
		let highByte = bytes[2]
		let idByte = bytes[0]

		return idByte == appID && LicenseCode.magicByteRange.contains(highByte)
	}

}
