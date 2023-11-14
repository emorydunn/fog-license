//
//  LicenseCode.swift
//  
//
//  Created by Emory Dunn on 10/16/23.
//

import Foundation
import ByteKit

protocol CodeSeed {
	var magicByteRange: ClosedRange<UInt8> { get }

	var magicByte: UInt8 { get }
	var standardByte: UInt8 { get }
}

/// A 32-bit license code.
///
/// A code is made up of three little endian bytes:
///
/// 0. The App ID
/// 1. Random 8-bit number
/// 2. Random 8-bit number within a clamped range
/// 3. Random 8-bit number
///
/// Byte 2 is clamped to a set range to act as magic number for quickly verifying the code is valid and not just a random guess.
public struct LicenseCode: Codable, ExpressibleByIntegerLiteral, Identifiable, Comparable, Hashable {
	public static func < (lhs: LicenseCode, rhs: LicenseCode) -> Bool {
		lhs.number < rhs.number
	}

//	static func == (lhs: LicenseCode, rhs: LicenseCode) -> Bool {
//		lhs.number == rhs.number
//	}

	static var seed: CodeSeed = Standard()

	let byte0: UInt8
	let byte1: UInt8
	let byte2: UInt8
	let byte3: UInt8

	public var id: UInt32 { number }

	public var number: UInt32 {
		return UInt32(from: bytes)
	}

	var bytes: [UInt8] {
		[
			byte0,
			byte1,
			byte2,
			byte3
		]
	}

	public init(_ code: UInt32) {
		let bytes = code.bytes()

		self.byte3 = bytes[3]
		self.byte2 = bytes[2]
		self.byte1 = bytes[1]
		self.byte0 = bytes[0]
	}

	public init(integerLiteral value: IntegerLiteralType) {
		self.init(UInt32(truncatingIfNeeded: value))
	}


	public init?(_ bytes: UInt8...) {
		guard bytes.count == 4 else { return nil }
		self.byte3 = bytes[3]
		self.byte2 = bytes[2]
		self.byte1 = bytes[1]
		self.byte0 = bytes[0]
	}

	public init?(_ bytes: [UInt8]) {
		guard bytes.count == 4 else { return nil }
		self.byte3 = bytes[3]
		self.byte2 = bytes[2]
		self.byte1 = bytes[1]
		self.byte0 = bytes[0]
	}

	public init(appID: UInt8) {
		self.byte3 = LicenseCode.seed.standardByte // Secret extra byte in case I run out of codes
		self.byte2 = LicenseCode.seed.magicByte
		self.byte1 = LicenseCode.seed.standardByte
		self.byte0 = appID
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let bytes = try container.decode(UInt32.self).bytes(littleEndian: false)

		self.byte3 = bytes[3]
		self.byte2 = bytes[2]
		self.byte1 = bytes[1]
		self.byte0 = bytes[0]

	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(self.number)
	}

	/// Test whether the license code is matches the specified App ID.
	/// - Parameter appID: The identifier of an application.
	/// - Returns: Whether the license code is valid.
	public func isValid(for appID: UInt8) -> Bool {
		byte0 == appID && LicenseCode.seed.magicByteRange.contains(byte2)
	}

}

extension LicenseCode {
	public struct FormatStyle: Foundation.FormatStyle, ParseableFormatStyle, ParseStrategy {

		public enum CodeStyle: String, Codable, CaseIterable, Identifiable, CustomStringConvertible {

			public var id: String { rawValue }

			case integer
			case bytes
			case hexBytes

			public var description: String {
				switch self {
				case .integer:
					return "Integer"
				case .bytes:
					return "Bytes"
				case .hexBytes:
					return "Bytes (hex)"
				}
			}
		}

		let style: CodeStyle
		public var parseStrategy: FormatStyle {
			FormatStyle(style: style)
		}


		public func format(_ value: LicenseCode?) -> String {
			guard let value else { return "" }

			switch style {
			case .integer:
				return String(value.number, radix: 10)
			case .bytes:
				return formatBytes(value, useHex: false)
			case .hexBytes:
				return formatBytes(value, useHex: true)
			}
		}

		public func parse(_ value: String) -> LicenseCode? {

			// Don't bother parsing an empty string
			guard !value.isEmpty else {
				return nil
			}

			// Number can be at most 10 digits long,
			// otherwise it overflows UInt32
			guard value.count <= 10 else {
				return nil
			}

			switch style {
			case .integer:
				if let number = UInt32(value, radix: 10) {
					return LicenseCode(number)
				}
				return nil
			case .bytes:
				let bytes = value
					.components(separatedBy: " ")
					.compactMap { value -> UInt8? in
						UInt8(value, radix: 10)
					}

				return LicenseCode(bytes)

			case .hexBytes:
				let bytes = value
					.components(separatedBy: " ")
					.compactMap { value in
						UInt8(value, radix: 16)
					}

				return LicenseCode(bytes)

			}

		}

		func formatBytes(_ value: LicenseCode, useHex: Bool) -> String {
			return value.bytes.map {
				if useHex {
					return $0.formatted(.hex(uppercase: true, includePrefix: false))
				}

				return $0.formatted()
			}
			.joined(separator: " ")
		}

	}

	public func formatted(_ style: FormatStyle.CodeStyle = .integer) -> String {
		FormatStyle(style: style).format(self)
	}

}

extension FormatStyle where Self == LicenseCode.FormatStyle {
	public static func licenseCode(_ style: LicenseCode.FormatStyle.CodeStyle) -> LicenseCode.FormatStyle { LicenseCode.FormatStyle(style: style) }
//	public static var licenseCodeHex: LicenseCode.FormatStyle { LicenseCode.FormatStyle(hex: false) }
}

extension LicenseCode {
	struct Standard: CodeSeed {

		let magicByteRange = UInt8.min...0x42

		var magicByte: UInt8 {
			UInt8.random(in: UInt8.min..<0x42)
		}
	
		var standardByte: UInt8 {
			UInt8.random(in: UInt8.min..<UInt8.max)
		}
	}
}

