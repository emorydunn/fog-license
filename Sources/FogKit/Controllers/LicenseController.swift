//
//  LicenseController.swift
//
//
//  Created by Emory Dunn on 11/7/23.
//

import Foundation
import OSLog
import SharedModels

fileprivate let logger = Logger(subsystem: "FogKit", category: "LicenseController")

public struct LicenseController: EndpointController {
	let client: FogClient

	let endpointURL: URL

	init(client: FogClient) {
		self.client = client
		self.endpointURL = client.endpointURL.appending(component: "licenses")
	}
	
	/// List licenses associated with the given email address.
	/// - Parameters:
	///   - email: The email address to search for.
	///   - app: Specify an app to limit the scope of the search.
	/// - Returns: An array of `SoftwareLicense` objects.
	public func list(for email: String, and app: AppInfo? = nil) async throws -> [SoftwareLicense] {
		let url = endpointURL.appending(queryItems: [
			URLQueryItem(name: "email_address", value: email),
			URLQueryItem(name: "bundle_identifier", value: app?.bundleIdentifier),
		])

		let request = URLRequest(url: url)

		let (data, _) = try await session.data(for: request,
											   decoding: [SoftwareLicense].self,
											   expectedCodes: 200,
											   with: decoder)

		return data
	}

	func get() async throws {

	}

	func create() async throws {

	}

	public func update(_ license: SoftwareLicense) async throws -> SoftwareLicense {
		var request = URLRequest(url: endpointURL.appending(components: license.code.formatted(.integer)))

		request.httpMethod = "PUT"
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
		request.httpBody = try encoder.encode(license)

		let (softLicense, _) = try await session.data(for: request,
													  decoding: SoftwareLicense.self,
													  expectedCodes: 200,
													  with: decoder)

		return softLicense
	}

	func deactivate() async throws {

	}

	// MARK: Activations

	/// Create an `ActivationRequest` and post it to the server.
	/// - Parameters:
	///   - license: The `LicenseCode` to activate.
	///   - app: The application for the request.
	///   - computer: The hardware for the request.
	/// - Returns: An `ActivatedLicense`.
	public func activateLicense(_ license: LicenseCode, bundleIdentifier: String, computer: HardwareIdentifier) async throws -> ActivatedLicense {
		logger.log("Activating license \(license.formatted(.hexBytes)) for \(computer.computerName)")
		let hashedHardwareID = computer.hashDescription()
		
		let activationRequest = SoftwareLicense.ActivationRequest(bundleIdentifier: bundleIdentifier,
																  hardwareIdentifier: hashedHardwareID,
																  computerName: computer.computerName,
																  computerModel: computer.computerModel,
																  osVersion: computer.osVersion)

		return try await activateLicense(license, activationRequest: activationRequest)
	}

	/// Attempt to reactivate an existing activation.
	/// - Parameter activatedLicense: The license to verify.
	/// - Returns: An `ActivatedLicense`.
	public func activateLicense(_ activatedLicense: ActivatedLicense) async throws -> ActivatedLicense {

		// Validate the license
		guard
			let license = activatedLicense.license,
			let activation = activatedLicense.activation else {
			logger.warning("Can't activate license without a license and hardware identifier")
			return activatedLicense
		}

		let activationRequest = SoftwareLicense.ActivationRequest(bundleIdentifier: license.bundleIdentifier,
																  hardwareIdentifier: activation.hardwareIdentifier)

		return try await activateLicense(license.code, activationRequest: activationRequest)

	}

	public func activateLicense(_ license: LicenseCode, activationRequest: SoftwareLicense.ActivationRequest) async throws -> ActivatedLicense {

		var request = URLRequest(url: endpointURL.appending(components:license.formatted(.integer), "activation"))

		request.httpMethod = "POST"
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
		request.httpBody = try encoder.encode(activationRequest)

		let (softLicense, response) = try await session.data(for: request,
															 decoding: SoftwareLicense.self,
															 expectedCodes: 202,
															 with: decoder)

		guard let token = response.bearerAuthorization else {
			throw ServerError.missingToken
		}

		logger.info("Verifying JWT token")
		let activation = try signer.verify(token, as: SignedVerification.self)

		// Double check the token and the license match
		guard
			activation.bundleIdentifier.value == softLicense.bundleIdentifier,
			activation.licenseCode == softLicense.code,
			activation.hardwareIdentifier == activationRequest.hardwareIdentifier
		else {
			throw ServerError.invalidLicense
		}

		return .activated(license: softLicense, activation: activation, token: token)
	}

	public func deactivate(license: LicenseCode, activation: SignedVerification) async throws {
		var request = URLRequest(url: endpointURL.appending(components: license.formatted(.integer), "activation"))

		request.httpMethod = "DELETE"
		request.addValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")

		request.httpBody = activation.hardwareIdentifier.data(using: .utf8)

		let (_, response) = try await session.data(for: request)

		guard let response = response as? HTTPURLResponse else { fatalError("Should be HTTP response") }

		logger.log("\(response.statusCode) \(request.url!.relativePath)")

	}

}
