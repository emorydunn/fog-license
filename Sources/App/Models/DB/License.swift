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

final class LicenseModel: Model, Content {
	static let schema = "license"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "date")
	var date: Date

	@OptionalField(key: "expiry_date")
	var expiryDate: Date?

	@Field(key: "code")
	var code: LicenseCode

	@Field(key: "allowed_activation_count")
	var activationCount: Int

	@Field(key: "is_active")
	var isActive: Bool

//	@Field(key: "payment_id")
//	var paymentID: String?
//
//	@Field(key: "subscription_id")
//	var subscriptionID: String?

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

	init() { }

	init(app: App, user: User, date: Date = Date(), isActive: Bool = true, expiryDate: Date? = nil) throws {
		self.date = date
		self.expiryDate = expiryDate
		self.isActive = isActive
//		self.paymentID = payment.id
		self.code = LicenseCode(appID: app.number)
		self.activationCount = app.activationCount

		self.$application.id = try app.requireID()
		self.$user.id = try user.requireID()
	}

	init(code: LicenseCode, activationCount: Int, application: App.IDValue, user: User.IDValue, date: Date = Date(), expiryDate: Date? = nil) {
		self.date = date
		self.expiryDate = expiryDate
		self.code = code
		self.activationCount = activationCount
//		self.paymentID = payment

		self.$application.id = application
		self.$user.id = user
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

//struct SoftwareLicense: Codable {
//	let code: LicenseCode
//	let application: String
//	let name: String
//	let email: String
//	let date: Date
//}
