//
//  UserTests.swift
//
//
//  Created by Emory Dunn on 10/16/23.
//

import Foundation
@testable import App
import XCTVapor

final class UserTests: XCTestCase {
	// MARK: Server Tests
	func testCreateUser() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		try server.test(.POST, "/api/v1/users") { req in
			try req.content.encode(User.test, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .ok)
			let newModel = try res.content.decode(User.self)
			XCTAssertEqual(newModel.name, "Test User")
		}
	}

	func testListUser() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		try await User.saveTest(on: server.db)

		let path = "/api/v1/users"
		try server.test(.GET, path) { res in
			XCTAssertEqual(res.status, .ok)
			let apps = try res.content.decode([User].self)
			XCTAssertEqual(apps.count, 1)
		}
	}

	func testGetUser() async throws {
		let server = Application(.testing)
		server.logger.logLevel = .trace
		defer { server.shutdown() }
		try await configure(server)

		let newModel = try await User.saveTest(on: server.db)

		let path = "/api/v1/users/\(try newModel.requireID())"
		try server.test(.GET, path) { res in
			XCTAssertEqual(res.status, .ok)
			let newModel = try res.content.decode(User.self)
			XCTAssertEqual(newModel.name, "Test User")
		}
	}

	func testDeleteUser() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let newModel = try await User.saveTest(on: server.db)

		let path = "/api/v1/users/\(try newModel.requireID())"
		try server.test(.DELETE, path) { res in
			XCTAssertEqual(res.status, .noContent)
		}
	}
}
