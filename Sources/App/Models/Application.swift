//
//  File.swift
//  
//
//  Created by Emory Dunn on 10/12/23.
//

import Foundation
import Vapor
import Fluent

final class App: Model, Content {
	static let schema = "application"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "number")
	var number: UInt8

	@Field(key: "bundle_id")
	var bundleID: String

	@Field(key: "name")
	var name: String

	@Field(key: "default_activation_count")
	var activationCount: Int

	@Field(key: "purchase_id")
	var purchaseID: String

	@Field(key: "subscription_id")
	var subscriptionID: String?

	init() {}

	init(name: String, bundleID: String, number: UInt8, activationCount: Int = 3, purchaseID: String, subscriptionID: String?) {
		self.name = name
		self.number = number
		self.bundleID = bundleID
		self.activationCount = activationCount
		self.purchaseID = purchaseID
		self.subscriptionID = subscriptionID
	}

	init(name: String, bundleID: String, activationCount: Int = 3, purchaseID: String, subscriptionID: String?, on database: Database) async throws {
		self.name = name
		self.number = UInt8(try await App.query(on: database).count() + 1)
		self.bundleID = bundleID
		self.activationCount = activationCount
		self.purchaseID = purchaseID
		self.subscriptionID = subscriptionID
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
			database.logger.log(level: .debug, "Can't find app without an id")
			return nil
		}
		
		database.logger.log(level: .debug, "Finding app with bundle ID or name \(id)")
		return try await App.query(on: database)
			.group(.or) { group in
					group.filter(\.$bundleID == id)
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
