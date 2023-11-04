//
//  LicenseController.swift
//
//
//  Created by Emory Dunn on 10/30/23.
//

import Foundation
import Vapor
import SharedModels
import Fluent
import JWT

struct LicenseQuery: Codable {

	enum CodingKeys: String, CodingKey {
		case bundleIdentifier = "bundle_identifier"
		case emailAddress = "email_address"
	}

	let bundleIdentifier: String?
	let emailAddress: String
}

struct LicenseController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let routeGroup = routes.grouped("licenses")

		routeGroup.get(use: index)
		routeGroup.post(use: create)
		routeGroup.group(":licenseID") { group in
			group.delete(use: deactivateLicense)
			group.get(use: fetch)

			group.group("activation") { activation in
				activation.post(use: activate)
				activation.delete(use: deactivateMachine)
			}

		}

	}

	func index(req: Request) async throws -> [SoftwareLicense] {

		let query = try req.query.decode(LicenseQuery.self)

		let licenses = try await LicenseModel.query(on: req.db)
			.join(User.self, on: \LicenseModel.$user.$id == \User.$id)
			.join(App.self, on: \LicenseModel.$application.$id == \App.$id)
			.group(.and) { group in
				group.filter(User.self, \.$email == query.emailAddress)

				if let bundleIdentifier = query.bundleIdentifier {
					group.filter(App.self, \.$bundleIdentifier == bundleIdentifier)
				}
			}
			.all()

		return try await withThrowingTaskGroup(of: SoftwareLicense.self, returning: [SoftwareLicense].self) { group in
			for license in licenses {
				group.addTask {
					try await SoftwareLicense(license, on: req.db)
				}
			}

			var infos = [SoftwareLicense]()
			for try await app in group {
				infos.append(app)
			}

			return infos
		}
	}

	func fetch(req: Request) async throws -> SoftwareLicense {
		let license = try await LicenseModel.find(req: req)

		return try await SoftwareLicense(license, on: req.db)
	}

	func create(req: Request) async throws -> SoftwareLicense {
		let generate = try req.content.decode(SoftwareLicense.Generate.self)

		let app: App = try await App.find(generate.bundleIdentifier, on: req.db)
		let user = try await User.find(email: generate.customerEmail, on: req.db)

		let newModel = try LicenseModel(app: app, user: user,
											  date: generate.date ?? Date(),
											  isActive: generate.isActive ?? true,
											  expiryDate: generate.expiryDate)

		try await newModel.save(on: req.db)
		return try await SoftwareLicense(newModel, on: req.db)
	}
	

	func deactivateLicense(req: Request) async throws -> SoftwareLicense {

		let license = try await LicenseModel.find(req: req)

		license.isActive = false

		try await license.save(on: req.db)

		return try await SoftwareLicense(license, on: req.db)
	}

	// MARK: - Machine Activations
	/// Activate or validate a license.
	///
	/// Validation Steps:
	/// 1. Check if the license is active
	/// 2. Check activation count is under the limit
	/// 3. Check request bundle ID matches app bundle ID
	/// 4. Check license code is valid
	///
	/// Once validation passes the computer info is saved and an `Activation` is created.
	/// - Parameter req: The HTTP request
	/// - Returns: A `SoftwareLicense` and a JWT token as the auth header.
	/// - Throws: 403, 404
	func activate(req: Request) async throws -> Response {

		let license = try await LicenseModel.find(req: req)

		// Ensure the license is active
		guard license.isActive else {
			throw Abort(.forbidden, reason: "License '\(license.code.formatted(.integer))' is inactive.")
		}

		// Load the relationships for additional verification
		try await license.$application.load(on: req.db)
		try await license.$user.load(on: req.db)

		let bundleIdentifier: String = try req.content.get(at: "bundleIdentifier")

		// Ensure the bundle ID from the request matches the app the license belongs to
		guard
			license.application.bundleIdentifier == bundleIdentifier
		else {
			throw Abort(.forbidden, reason: "Provided bundle identifier does not match the application's bundle identifier.")
		}

		// Ensure the license code is valid (should also be done client side)
		// This should only ever fail if the app's magic number is changed
		// _after_ license creation, which would invalidate _every_ code. Don't do that.
		guard
			license.code.isValid(for: license.application.number)
		else {
			throw Abort(.forbidden, reason: "Not a valid \(license.application.name) license code.")
		}

		return try await req.db.transaction { db in
			// Decode the computer info
			let hardwareInfo = try await ComputerInfo.decode(request: req, updatingExisting: true, on: db)

			try await hardwareInfo.save(on: db)

			let hardwareInfoID = try hardwareInfo.requireID()
			let licenseID = try license.requireID()

			let activation: Activation = try await Activation.find(license: licenseID, computer: hardwareInfoID, on: db)

			// Clear any deactivation date and increment the counter
			activation.verificationCount += 1

			if activation.deactivatedDate == nil {
				req.logger.debug("Saving activation")
				try await activation.save(on: db)
			} else {
				req.logger.debug("Restoring activation")
				try await activation.restore(on: db)
			}

			// Fetch the current activation count
			let activationCount = try await license.activationCount(on: db)

			req.logger.info("\(license.code.formatted(.hexBytes)) has \(activationCount) / \(license.activationLimit) activations")

			// Check if we've reached the limit
			// Including this activation, are we under the limit?
			guard activationCount <= license.activationLimit else {
				throw Abort(.forbidden, reason: "Activation limit of \(license.activationLimit) computers reached for license '\(license.code.formatted(.integer))'.")
			}

			req.logger.notice("Activated license \(license.code.formatted(.hexBytes))")

			// The when the app should verify the license again
			let expiration = Calendar.current.date(byAdding: .day, value: 5, to: activation.lastVerified ?? Date.now)
			let payload = SignedActivation(bundleIdentifier: license.application.bundleIdentifier,
										   expiration: expiration!,
										   licenseCode: license.code,
										   hardwareIdentifier: hardwareInfo.hardwareIdentifier)

			let token = try req.jwt.sign(payload)

			let softLicense = SoftwareLicense(license, activationCount: activationCount)
			let response = Response(status: .accepted)
			try response.content.encode(softLicense)

			response.headers.bearerAuthorization = .init(token: token)
			return response

		}

	}

	func deactivateMachine(req: Request) async throws -> Response {

		// Look up the license from the query
		let license = try await LicenseModel.find(req: req)

		// Decode the hardware from the body
		guard 
			let hardwareID = req.body.string,
			let hardwareInfo = try await ComputerInfo.find(hardwareIdentifier: hardwareID, on: req.db)
		else { return Response(status: .badRequest) }
		//		let hardwareInfo = try await ComputerInfo.decode(request: req, updatingExisting: true, on: req.db)

		// Find the activation, if it doesn't exist there's nothing to do
		let activation: Activation? = try await Activation.find(license: try license.requireID(),
						computer: try hardwareInfo.requireID(),
						on: req.db)

		// Soft-delete the activation
		try await activation?.delete(on: req.db)

		return Response(status: .accepted)
	}

}


