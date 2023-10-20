//
//  ReceiptTests.swift
//  
//
//  Created by Emory Dunn on 10/18/23.
//

import Foundation
@testable import App
import XCTVapor

final class ReceiptTests: XCTestCase {
	// MARK: Server Tests

	func testCreateReceipt() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let date = Date.now

		try server.test(.POST, "/api/v1/receipts") { req in

			let newLicense = try LicenseModel(app: app, user: user, isActive: false)
			let receipt = Receipt.Create(date: date, paymentID: "pi_12345", licenses: [newLicense])

			try req.content.encode(receipt, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .ok)
			let newModel = try res.content.decode(Receipt.Create.self)


			XCTAssertEqual(newModel.date.rfc1123,
						   date.rfc1123)
			XCTAssertEqual(newModel.licenses.count, 1)
		}
	}

	func testGetReceipt() async throws {
		let server = Application(.testing)
		server.logger.logLevel = .trace
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let newLicense = try LicenseModel(app: app, user: user, isActive: false)

		let newModel = Receipt(paymentID: "pi_12345")
		try await newModel.save(on: server.db)

		try await newModel.addLicense(newLicense, on: server.db)

		let path = "/api/v1/receipts/\(try newModel.requireID())"
		try server.test(.GET, path) { res in
			XCTAssertEqual(res.status, .ok)
			let newModel = try res.content.decode(Receipt.Create.self)
			XCTAssertEqual(newModel.paymentID, "pi_12345")
		}
	}

	func testDeleteReceipt() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let newLicense = try LicenseModel(app: app, user: user, isActive: false)

		let newModel = Receipt(paymentID: "pi_12345")
		try await newModel.save(on: server.db)

		try await newModel.addLicense(newLicense, on: server.db)

		let path = "/api/v1/receipts/\(try newModel.requireID())"
		try server.test(.DELETE, path) { res in
			XCTAssertEqual(res.status, .noContent)
		}
	}
}
