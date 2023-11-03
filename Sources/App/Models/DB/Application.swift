//
//  File.swift
//  
//
//  Created by Emory Dunn on 10/12/23.
//

import Foundation
import Vapor
import Fluent
import SharedModels
import StripeKit

final class App: Model, Content {
	static let schema = "application"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "number")
	var number: UInt8

	@Field(key: "bundle_id")
	var bundleIdentifier: String

	@Field(key: "name")
	var name: String

	@Field(key: "default_activation_count")
	var activationCount: Int

	@Field(key: "purchase_id")
	var purchaseID: String

	@OptionalField(key: "subscription_id")
	var subscriptionID: String?

	@Children(for: \.$application)
	var licenses: [LicenseModel]

	init() {}

	init(name: String, bundleID: String, number: UInt8, activationCount: Int = 3, purchaseID: String, subscriptionID: String?) {
		self.name = name
		self.number = number
		self.bundleIdentifier = bundleID
		self.activationCount = activationCount
		self.purchaseID = purchaseID
		self.subscriptionID = subscriptionID
	}

	init(name: String, bundleID: String, activationCount: Int = 3, purchaseID: String, subscriptionID: String?, on database: Database) async throws {
		self.name = name
		self.number = UInt8(try await App.query(on: database).max(\.$number) ?? 0 + 1)
		self.bundleIdentifier = bundleID
		self.activationCount = activationCount
		self.purchaseID = purchaseID
		self.subscriptionID = subscriptionID
	}

	init(_ stub: Stub, on database: Database) async throws {
		self.name = stub.name
		self.number = UInt8(try await App.query(on: database).max(\.$number) ?? 0 + 1)
		self.bundleIdentifier = stub.bundleIdentifier
		self.activationCount = stub.activationCount
		self.purchaseID = stub.purchaseID
		self.subscriptionID = stub.subscriptionID
	}

	init(_ stub: AppInfo, on database: Database) async throws {
		self.name = stub.name
		self.number = UInt8(try await App.query(on: database).max(\.$number) ?? 0 + 1)
		self.bundleIdentifier = stub.bundleIdentifier
		self.activationCount = stub.activationCount
		self.purchaseID = stub.purchase.id
		self.subscriptionID = stub.subscription?.id
	}

	struct Stub: Content {
		let name: String
		let bundleIdentifier: String
		let activationCount: Int
		let purchaseID: String
		let subscriptionID: String?
	}

	func expirationDate(anchorDate: Date = .now) -> Date? {
		guard subscriptionID != nil else { return nil }
		return Calendar.current.date(byAdding: .year, value: 1, to: anchorDate)
	}

}

extension App {
	/// Look up an application with the given ID.
	///
	/// The given ID can be either the full Bundle ID or the Name of the app.
	///
	/// - Parameters:
	///   - id: Either a Bundle ID or app name.
	///   - database: The database to search.
	/// - Returns: An `App`, if one matches the query.
	static func find(_ id: String?, on database: Database) async throws -> App? {
		guard let id else {
			database.logger.log(level: .warning, "Can't find app without an id")
			return nil
		}
		
		database.logger.log(level: .info, "Finding app with bundle ID or name \(id)")
		return try await App.query(on: database)
			.group(.or) { group in
					group.filter(\.$bundleIdentifier == id)
					group.filter(\.$name == id)
			}
			.first()
	}

	static func find(_ id: String?, on database: Database, orThrow status: HTTPResponseStatus = .notFound) async throws -> App {
		guard
			let app = try await App.find(id, on: database)
		else {
			database.logger.log(level: .error, "Application \(id ?? "") does not exist")
			throw Abort(status)
		}

		return app
	}
}
