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

struct LicenseController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let routeGroup = routes.grouped("licenses")

		routeGroup.get(use: index)
		routeGroup.post(use: create)
		routeGroup.group(":licenseID") { group in
//			todo.get(use: getUser)
//			todo.delete(use: delete)
			group.post("activate", use: activate)
			group.delete("activate", use: activate)
		}

	}

	func index(req: Request) async throws -> [SoftwareLicense] {

		let bundleIdentifier = try? req.query.get(String.self, at: "bundle_identifier")
		let emailAddress = try req.query.get(String.self, at: "email_address")

		let licenses = try await LicenseModel.query(on: req.db)
			.join(User.self, on: \LicenseModel.$user.$id == \User.$id)
			.join(App.self, on: \LicenseModel.$application.$id == \App.$id)
			.group(.and) { group in
				group.filter(User.self, \.$email == emailAddress)

				if let bundleIdentifier {
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
	func activate(req: Request) async throws -> Response {

		guard 
			let number = req.parameters.get("licenseID", as: UInt32.self),
			let license = try await LicenseModel.query(on: req.db)
				.filter(\.$code == LicenseCode(number))
				.first()
		else {
			throw Abort(.notFound, reason: "Could not find license to activate")
		}

		// Ensure the license is active
		guard license.isActive else {
			throw Abort(.forbidden, reason: "License \(license.code.formatted(.hexBytes)) is not active.")
		}

		// Fetch the current activation count
		let activationCount = try await license.activationCount(on: req.db)

		// Check if we've reached the limit
		guard activationCount < license.activationLimit else {
			throw Abort(.forbidden, reason: "Activation limit \(license.activationLimit) reached for license \(license.code.formatted(.hexBytes))")
		}

		// Load the app for additional verification
		try await license.$application.load(on: req.db)

		print(req.body.string ?? "")

		let bundleIdentifier: String = try req.content.get(at: "bundleIdentifier")

		// Ensure the bundle ID from the request matches the app the license belongs to
		guard
			license.application.bundleIdentifier == bundleIdentifier
		else {
			throw Abort(.badRequest, reason: "Provided bundle identifier does not match the application's bundle identifier")
		}

		// Ensure the license code is valid (should also be done client side)
		guard
			license.code.isValid(for: license.application.number)
		else {
			throw Abort(.forbidden, reason: "License \(license.code.formatted(.hexBytes)) is not valid for application \(license.application.bundleIdentifier)")
		}

		return try await req.db.transaction { db in
			// Decode the computer info
			let hardwareInfo = try await ComputerInfo.decode(request: req, updatingExisting: true, on: db)

			try await hardwareInfo.save(on: db)

			let hardwareInfoID = try hardwareInfo.requireID()
			let licenseID = try license.requireID()

			let activation = try await Activation.find(license: licenseID, computer: hardwareInfoID, on: db)

			activation.verificationCount += 1

			try await activation.save(on: db)
			req.logger.notice("Activated license \(license.code.formatted(.hexBytes))")

			// The when the app should verify the license again
			let expiration = Calendar.current.date(byAdding: .day, value: 5, to: activation.lastVerified ?? Date.now)
			let payload = SignedActivation(bundleIdentifier: license.application.bundleIdentifier,
										   expiration: expiration!,
										   licenseCode: license.code)

			let token = try req.jwt.sign(payload)

			let softLicense = SoftwareLicense(license, activationCount: activationCount)
			let response = Response(status: .ok)
			try response.content.encode(softLicense)

			response.headers.bearerAuthorization = .init(token: token)
			return response

		}

	}

}


