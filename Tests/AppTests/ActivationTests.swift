//
//  ActivationTests.swift
//  
//
//  Created by Emory Dunn on 11/3/23.
//

import XCTest
@testable import App
import XCTVapor
import SharedModels

final class ActivationTests: XCTestCase {

	
	// MARK: Search Tests
	func testFind() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)
		let comp = try await ComputerInfo.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		try await license.save(on: server.db)

		let activation = Activation()

		activation.$license.id = try license.requireID()
		activation.$computer.id = try comp.requireID()
		activation.verificationCount = 0

		try await activation.save(on: server.db)

		let found: Activation = try await Activation.find(license: try license.requireID(),
														  computer: try comp.requireID(),
														  on: server.db)

		// Ensure the saved model out queried model match
		XCTAssertEqual(activation.id, found.id)
	}

	func testFind_Create() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)
		let comp = try await ComputerInfo.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		try await license.save(on: server.db)

		let found: Activation = try await Activation.find(license: try license.requireID(),
														  computer: try comp.requireID(),
														  on: server.db)

		// ID will be nil because the model hasn't been saved
		XCTAssertNil(found.id)
	}

	// MARK: Server Tests

	func testActivation() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		try await license.save(on: server.db)

		let request = SoftwareLicense.ActivationRequest(bundleIdentifier: app.bundleIdentifier,
														hardwareIdentifier: "fakecomputer",
														computerName: "Fake Computer",
														computerModel: "Fake1,1",
														osVersion: "14.0.0")

		let path = "/api/v1/licenses/\(license.code.number)/activation"
		try server.test(.POST, path) { req in
			try req.content.encode(request, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .accepted)
			let result = try res.content.decode(SoftwareLicense.self)
			XCTAssertEqual(result.bundleIdentifier, app.bundleIdentifier)

			XCTAssertNotNil(res.headers.bearerAuthorization?.token)

		}
	}

	func testDeactivation() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)
		let comp = try await ComputerInfo.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		try await license.save(on: server.db)

		let activation = Activation()

		activation.$license.id = try license.requireID()
		activation.$computer.id = try comp.requireID()
		activation.verificationCount = 0

		try await activation.save(on: server.db)
		let path = "/api/v1/licenses/\(license.code.number)/activation"
		try server.test(.DELETE, path) { req in
			try req.content.encode(comp, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .accepted)
		}
	}

	func testReactivation() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)
		let comp = try await ComputerInfo.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		try await license.save(on: server.db)

		let activation = Activation()

		activation.$license.id = try license.requireID()
		activation.$computer.id = try comp.requireID()
		activation.verificationCount = 1

		try await activation.save(on: server.db)

		try await activation.delete(on: server.db)

		XCTAssertNotNil(activation.id)
		XCTAssertNotNil(activation.deactivatedDate)

		let request = SoftwareLicense.ActivationRequest(bundleIdentifier: app.bundleIdentifier,
														hardwareIdentifier: "fakecomputer",
														computerName: "Fake Computer",
														computerModel: "Fake1,1",
														osVersion: "14.0.0")

		let path = "/api/v1/licenses/\(license.code.number)/activation"
		try server.test(.POST, path) { req in
			try req.content.encode(request, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .accepted)
			XCTAssertNoThrow(try res.content.decode(SoftwareLicense.self))
		}

		guard let act = try await Activation.find(activation.id, on: server.db) else {
			XCTFail("Could not find Activation")
			return
		}

		XCTAssertNil(act.deactivatedDate)
		XCTAssertEqual(act.verificationCount, 2)
	}

	// MARK: Activation Errors

	func testActivation_InactiveLicense() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		license.isActive = false
		try await license.save(on: server.db)

		let request = SoftwareLicense.ActivationRequest(bundleIdentifier: app.bundleIdentifier,
														hardwareIdentifier: "fakecomputer",
														computerName: "Fake Computer",
														computerModel: "Fake1,1",
														osVersion: "14.0.0")

		let path = "/api/v1/licenses/\(license.code.number)/activation"
		try server.test(.POST, path) { req in
			try req.content.encode(request, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .forbidden)

		}
	}

	func testActivation_LimitReached() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		license.activationLimit = 0
		try await license.save(on: server.db)

		let request = SoftwareLicense.ActivationRequest(bundleIdentifier: app.bundleIdentifier,
														hardwareIdentifier: "fakecomputer",
														computerName: "Fake Computer",
														computerModel: "Fake1,1",
														osVersion: "14.0.0")

		let path = "/api/v1/licenses/\(license.code.number)/activation"
		try server.test(.POST, path) { req in
			try req.content.encode(request, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .forbidden)

		}
	}

	func testActivation_AppMismatch() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		try await license.save(on: server.db)

		let request = SoftwareLicense.ActivationRequest(bundleIdentifier: "com.other.app",
														hardwareIdentifier: "fakecomputer",
														computerName: "Fake Computer",
														computerModel: "Fake1,1",
														osVersion: "14.0.0")

		let path = "/api/v1/licenses/\(license.code.number)/activation"
		try server.test(.POST, path) { req in
			try req.content.encode(request, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .forbidden)

		}
	}

	func testActivation_AppNumberMismatch() async throws {
		let server = Application(.testing)
		defer { server.shutdown() }
		try await configure(server)

		let app = try await App.saveTest(on: server.db)
		let user = try await User.saveTest(on: server.db)

		let license = try LicenseModel(app: app, user: user)
		try await license.save(on: server.db)

		app.number = 42
		try await app.save(on: server.db)

		let request = SoftwareLicense.ActivationRequest(bundleIdentifier: app.bundleIdentifier,
														hardwareIdentifier: "fakecomputer",
														computerName: "Fake Computer",
														computerModel: "Fake1,1",
														osVersion: "14.0.0")

		let path = "/api/v1/licenses/\(license.code.number)/activation"
		try server.test(.POST, path) { req in
			try req.content.encode(request, as: .json)
		} afterResponse: { res in
			XCTAssertEqual(res.status, .forbidden)

		}
	}

}
