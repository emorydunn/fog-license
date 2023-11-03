//
//  LicenseTests.swift
//  
//
//  Created by Emory Dunn on 11/3/23.
//

import XCTest
@testable import App
import XCTVapor
import SharedModels

final class LicenseTests: XCTestCase {

	func testList() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		try await license.save(on: server.db)

		let query = LicenseQuery(bundleIdentifier: app.bundleIdentifier,
								 emailAddress: user.email)

		let path = "/api/v1/licenses"
		try server.test(.GET, path) { req in
			try req.query.encode(query)
		} afterResponse:  { res in
			XCTAssertEqual(res.status, .ok)
			let result = try res.content.decode([SoftwareLicense].self)
			XCTAssertEqual(result.count, 1)
		}
	}

	func testCreate() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let license = SoftwareLicense.Generate(bundleIdentifier: app.bundleIdentifier, customerEmail: user.email)

		let path = "/api/v1/licenses"
		try server.test(.POST, path) { req in
			try req.content.encode(license, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .ok)
			let result = try res.content.decode(SoftwareLicense.self)
			XCTAssertEqual(result.bundleIdentifier, app.bundleIdentifier)
		}
	}

	func testFetch() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		try await license.save(on: server.db)

		let path = "/api/v1/licenses/\(license.code.number)"
		try server.test(.GET, path) { res in
			XCTAssertEqual(res.status, .ok)
			let result = try res.content.decode(SoftwareLicense.self)
			XCTAssertEqual(result.code, license.code)
		}
	}


	func testDeactivate() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		license.isActive = true
		try await license.save(on: server.db)

		let path = "/api/v1/licenses/\(license.code.number)"
		try server.test(.DELETE, path) { res in
			XCTAssertEqual(res.status, .ok)
			let result = try res.content.decode(SoftwareLicense.self)
			XCTAssertFalse(result.isActive)
		}
	}
}
