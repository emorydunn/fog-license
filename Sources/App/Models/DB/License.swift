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
import SharedModels

final class LicenseModel: Model, Content {
	static let schema = "license"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "date")
	var date: Date

	@OptionalField(key: "expiry_date")
//	@Timestamp(key: "expiry_date", on: .delete)
	var expiryDate: Date?

	@Field(key: "code")
	var code: LicenseCode

	@Field(key: "allowed_activation_count")
	var activationLimit: Int

	@Field(key: "is_active")
	var isActive: Bool

	@Parent(key: "application_id")
	var application: App

	@Parent(key: "user_id")
	var user: User

	@Siblings(through: ReceiptItem.self, from: \.$license, to: \.$receipt)
	var receipts: [Receipt]

	@OptionalChild(for: \.$license)
	var subscription: UpdateSubscription?

//	@OptionalParent(key: "receipt_item_id")
//	var receiptItem: ReceiptItem?

	@Children(for: \.$license)
	var activations: [Activation]

	init() { }

	init(app: App, user: User, date: Date = Date(), isActive: Bool = true, expiryDate: Date? = nil) throws {
		self.date = date
		self.expiryDate = expiryDate
		self.isActive = isActive
//		self.paymentID = payment.id
		self.code = LicenseCode(appID: app.number)
		self.activationLimit = app.activationCount

		self.$application.id = try app.requireID()
		self.$user.id = try user.requireID()
	}

	init(code: LicenseCode, activationCount: Int, application: App.IDValue, user: User.IDValue, date: Date = Date(), expiryDate: Date? = nil) {
		self.date = date
		self.expiryDate = expiryDate
		self.code = code
		self.activationLimit = activationCount
//		self.paymentID = payment

		self.$application.id = application
		self.$user.id = user
	}


	/// Query a database for the number of active activations for the license.
	/// - Parameter db: The Database to query.
	/// - Returns: The count of associated activations.
	func activationCount(on db: Database) async throws -> Int {
		try await self.$activations
			.query(on: db)
			.count()
	}

//	func generateSoftwareLicense(on db: Database) async throws -> SoftwareLicense {
//		return SoftwareLicense(code: code,
//							   application: application.bundleID,
//							   name: user.name,
//							   email: user.email,
//							   date: date)
//	}

//	func activateLicense
}

extension LicenseModel: CustomStringConvertible {
	var description: String {
		return "License \(code) \(application)"
	}
}

extension SoftwareLicense.Generate: Content {
//	struct Generate: Content {
////		let bundleIdentifier: String
////		let customerEmail: String
////		var date: Date?
////		var isActive: Bool?
////		var expiryDate: Date? = nil
//	}
}

extension SoftwareLicense: Content {
	init(_ license: LicenseModel, on db: Database) async throws {
		let activationCount = try await license.$activations.query(on: db).count()

		let user = try await license.$user.get(on: db)
		let app = try await license.$application.get(on: db)

		self.init(code: license.code,
				  name: app.name,
				  bundleIdentifier: app.bundleIdentifier,
				  customerName: user.name,
				  customerEmail: user.email,
				  date: license.date,
				  expiryDate: license.expiryDate,
				  isActive: license.isActive,
				  activationLimit: license.activationLimit,
				  activationCount: activationCount)
	}

	init(_ license: LicenseModel, activationCount: Int) {
		self.init(code: license.code,
				  name: license.application.name,
				  bundleIdentifier: license.application.bundleIdentifier,
				  customerName: license.user.name,
				  customerEmail: license.user.email,
				  date: license.date,
				  expiryDate: license.expiryDate,
				  isActive: license.isActive,
				  activationLimit: license.activationLimit,
				  activationCount: activationCount)
	}
}
