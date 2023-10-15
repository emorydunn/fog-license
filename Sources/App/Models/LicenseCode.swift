//
//  File.swift
//  
//
//  Created by Emory Dunn on 10/12/23.
//

import Foundation
import ByteKit
import Vapor
import Fluent
import StripeKit

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

final class LicenseModel: Model, Content {
	static let schema = "license"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "date")
	var date: Date

	@Field(key: "expiry_date")
	var expiryDate: Date?

	@Field(key: "code")
	var code: LicenseCode

	@Field(key: "allowed_activation_count")
	var activationCount: Int

	@Field(key: "is_active")
	var isActive: Bool

	@Field(key: "payment_id")
	var paymentID: String

	@Field(key: "subscription_id")
	var subscriptionID: String?

	@Parent(key: "application_id")
	var application: App

	@Parent(key: "user_id")
	var user: User

	init() { }

	init(app: App, user: User, payment: PaymentIntent, date: Date = Date(), expiryDate: Date? = nil) throws {
		self.date = date
		self.expiryDate = expiryDate
		self.paymentID = payment.id
		self.code = LicenseCode(appID: app.number)
		self.activationCount = app.activationCount

		self.$application.id = try app.requireID()
		self.$user.id = try user.requireID()
	}

	init(code: LicenseCode, activationCount: Int, payment: String, application: App.IDValue, user: User.IDValue, date: Date = Date(), expiryDate: Date? = nil) {
		self.date = date
		self.expiryDate = expiryDate
		self.code = code
		self.activationCount = activationCount
		self.paymentID = payment

		self.$application.id = application
		self.$user.id = user
	}

	func generateSoftwareLicense(on db: Database) async throws -> SoftwareLicense {
		return SoftwareLicense(code: code,
							   application: application.bundleID,
							   name: user.name,
							   email: user.email,
							   date: date)
	}
}

struct SoftwareLicense: Codable {
	let code: LicenseCode
	let application: String
	let name: String
	let email: String
	let date: Date
}
