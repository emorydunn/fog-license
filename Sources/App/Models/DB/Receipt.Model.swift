//
//  Receipt.swift
//  
//
//  Created by Emory Dunn on 10/16/23.
//

import Foundation
import Vapor
import Fluent

final class ReceiptItem: Model {

	static var schema: String = "receipt_item"

	@ID(key: .id)
	var id: UUID?

	@Parent(key: "receipt_id")
	var receipt: Receipt

	@Parent(key: "license_id")
	var license: LicenseModel

	@Field(key: "amount")
	var amount: Int

	@Field(key: "description")
	var description: String

	@Field(key: "requested_updates")
	var requestedUpdates: Bool

	init() { }

	init(id: UUID? = nil, receipt: Receipt, license: LicenseModel, amount: Int, description: String, requestedUpdates: Bool) throws {
		self.id = id
		self.$receipt.id = try receipt.requireID()
		self.$license.id = try license.requireID()
		self.amount = amount
		self.description = description
		self.requestedUpdates = requestedUpdates
	}

}

final class Receipt: Model, Content {

	static var schema: String = "receipt"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "date")
	var date: Date

	@Field(key: "payment_id")
	var paymentID: String

	@Siblings(through: ReceiptItem.self, from: \.$receipt, to: \.$license)
	var licenses: [LicenseModel]

	@Children(for: \.$receipt)
	var items: [ReceiptItem]

	init() {}

	init(id: UUID? = nil, date: Date = .now, paymentID: String) {
		self.id = id
		self.date = date
		self.paymentID = paymentID
	}

	func addLicense(_ license: LicenseModel, on db: Database, edit: @escaping (ReceiptItem) -> () = { _ in }) async throws {
		db.logger.log(level: .info, "Adding \(license.code) to receipt")
		// First, save the license in case it's new
		try await license.save(on: db)

		try await $licenses.attach(license, on: db, edit)
	}

	func addLicenses(_ licenses: [LicenseModel], on db: Database) async throws {
		db.logger.log(level: .info, "Adding \(licenses.count) to receipt")
		for license in licenses {
			try await license.save(on: db)
		}

		try await $licenses.attach(licenses, on: db)
	}

	func removeLicense(_ license: LicenseModel, on db: Database) async throws {
		db.logger.log(level: .info, "Removing license \(license.code) from receipt")
		try await $licenses.load(on: db)
		try await $licenses.detach(license, on: db)
	}

	func removeLicenses(_ licenses: [LicenseModel], on db: Database) async throws {
		db.logger.log(level: .info, "Removing \(licenses.count) from receipt")
		try await $licenses.load(on: db)
		try await $licenses.detach(licenses, on: db)
	}

	func removeLicenses(on db: Database) async throws {
		try await removeLicenses(licenses, on: db)
	}

}

extension Receipt {
	static func findPayment(_ id: String, on db: Database) async throws -> Receipt {
		guard 
			let receipt = try await Receipt
			.query(on: db)
			.filter(\.$paymentID == id)
			.with(\.$licenses)
			.first()
		else {
			throw Abort(.notFound, reason: "Receipt with payment id \(id) missing")
		}

		return receipt
	}
}

extension Receipt {
	struct Create: Content {
		let id: UUID?
		let date: Date
		let paymentID: String
		let licenses: [LicenseModel]

		init(date: Date = .now, paymentID: String, licenses: [LicenseModel]) {
			self.id = nil
			self.date = date
			self.paymentID = paymentID
			self.licenses = licenses
		}

		init(_ receipt: Receipt, on db: Database) async throws {

			try await receipt.$licenses.load(on: db)

			self.id = try receipt.requireID()
			self.date = receipt.date
			self.paymentID = receipt.paymentID
			self.licenses = receipt.licenses
		}
	}

}
