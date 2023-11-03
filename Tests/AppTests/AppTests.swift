@testable import App
import XCTVapor
import SharedModels

final class AppTests: XCTestCase {

	// MARK: Support Tests
	func testFindApp() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let newApp = try await App(App.test, on: server.db)
		try await newApp.save(on: server.db)

		let app = try await App.find("com.test.app", on: server.db)
		XCTAssertNotNil(app)
	}

	func testFindApp_Missing() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.find("org.test.app", on: server.db)
		XCTAssertNil(app)
	}

	func testFindApp_MissingThrow() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		do {
			_ = try await App.find("org.test.app", on: server.db, orThrow: .notFound)
			XCTFail("Expected test to throw")
		} catch { }
	}

	// MARK: Server Tests
	func testCreateApp() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		try server.test(.POST, "/api/v1/apps") { req in
			try req.content.encode(AppInfo.test, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .ok)
			let newApp = try res.content.decode(AppInfo.self)
			XCTAssertEqual(newApp.bundleIdentifier, "com.test.app")
		}
	}

	func testListApp() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let newApp = try await App(App.test, on: server.db)
		try await newApp.save(on: server.db)

		let path = "/api/v1/apps"
		try server.test(.GET, path) { res in
			XCTAssertEqual(res.status, .ok)
			let apps = try res.content.decode([AppInfo].self)
			XCTAssertEqual(apps.count, 1)
		}
	}

	func testGetApp() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let newApp = try await App(App.test, on: server.db)
		try await newApp.save(on: server.db)

		let path = "/api/v1/apps/\(newApp.bundleIdentifier)"
		try server.test(.GET, path) { res in
			XCTAssertEqual(res.status, .ok)
			let newApp = try res.content.decode(AppInfo.self)
			XCTAssertEqual(newApp.bundleIdentifier, "com.test.app")
		}
	}

	func testDeleteApp() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let newApp = try await App(App.test, on: server.db)
		try await newApp.save(on: server.db)

		let path = "/api/v1/apps/\(newApp.bundleIdentifier)"
		try server.test(.DELETE, path) { res in
			XCTAssertEqual(res.status, .noContent)
		}
	}
}

