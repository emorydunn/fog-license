//
//  FogProduct.swift
//
//
//  Created by Emory Dunn on 11/7/23.
//

import Foundation
import OSLog
import SharedModels

fileprivate let logger = Logger(subsystem: "FogKit", category: "FogProduct")

//@Observable
public class FogProduct: ObservableObject {

	@Published
	public private(set) var activationSate: ActivatedLicense = .inactive

//	@Published
//	public private(set) var app: AppInfo

	public private(set) var name: String
	public let bundleIdentifier: String
	public private(set) var appNumber: UInt8
	
	/// A boolean indicating whether the the app has been refreshed from the server. 
	public private(set) var isStale = true

	public init(app: AppInfo) {
		self.name = app.name
		self.bundleIdentifier = app.bundleIdentifier
		self.appNumber = app.number
	}

	public init(bundle: Bundle = .main, appNumber: UInt8 = UInt8.max) {
		guard
			let bundleIdentifier = bundle.bundleIdentifier,
			let bundleName = bundle.infoDictionary?["CFBundleName"] as? String
		else {
			preconditionFailure("Bundle is missing information.")
		}

		self.name = bundleName
		self.bundleIdentifier = bundleIdentifier
		self.appNumber = appNumber

	}

	public func storeActivation() throws {
		logger.log("Saving activation state to disk")
//		let data = try PropertyListEncoder().encode(activationSate)

		let licenseDir = try FileManager.default.url(for: .allLibrariesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

		print(licenseDir.absoluteString)
	}

	// MARK: - Server Calls
	public func refresh(using client: FogClient) {
		Task.detached {
			logger.info("Refreshing \(self.isStale ? "stale " : "")product from server.")
			let app = try await client.apps.get(bundleIdentifier: self.bundleIdentifier)

			await MainActor.run {
				self.name = app.name
				self.appNumber = app.number
				self.isStale = false
			}
		}
	}


	public func activateLicense(_ code: LicenseCode, using client: FogClient) async throws {

		logger.info("Activating license code \(code.formatted()).")
		guard let computer = HardwareIdentifier() else {
			logger.error("Could not read computer's hardware configuration.")
			throw ServerError.hardwareInfo
		}

		let state = try await client.licenses.activateLicense(code,
															  bundleIdentifier: bundleIdentifier,
															  computer: computer)

		await MainActor.run {
			self.activationSate = state
		}

		logger.info("Activated license with new state \(self.activationSate)")
	}

	public func verifyLicense(using client: FogClient) async throws {
		logger.info("Verifying activation with state \(self.activationSate)")

		guard activationSate.needsVerification else {
			logger.info("Activation state \(self.activationSate) doesn't need to be verified right now.")
			return
		}

		let state = try await client.licenses.activateLicense(activationSate)
		await MainActor.run {
			self.activationSate = state
		}
		
		logger.info("Verified activation with new state \(self.activationSate)")
	}

	/// Attempt to reactivate this machine.
	/// - Parameter activatedLicense: The license to verify.
	/// - Returns: An `ActivatedLicense`.
	public func reactivateLicense(using client: FogClient) async throws {

		// Validate the license
		guard
			let license = activationSate.license
		else {
			logger.warning("Can't reactivate without a license code")
			return
		}

		return try await activateLicense(license.code, using: client)

	}
	
	/// Deactivate the machine without removing the license.
	public func deactivateMachine(using client: FogClient) async throws {
		guard case .activated(let license, let activation, _) = activationSate else {
			logger.notice("This computer is not currently activated.")
			return
		}

		logger.info("Deactivating the license on this computer.")

		try await client.licenses.deactivate(license: license.code, activation: activation)

		await MainActor.run {
			self.activationSate = .licensed(license: license, activation: activation)
		}

		logger.info("Computer has successfully been deactivated.")
	}
	
	/// Deactivate and remove the license from the machine.
	public func removeLicense(using client: FogClient) async throws {

		switch activationSate {
		case .activated(let license, let activation, _):
			logger.info("Deactivating machine and removing the license.")
			try await client.licenses.deactivate(license: license.code, activation: activation)
			
			await MainActor.run {
				activationSate = .inactive
			}

		case .licensed:
			logger.info("Removing the current license.")
			
			await MainActor.run {
				activationSate = .inactive
			}

		case .inactive:
			logger.notice("This computer is not licensed.")
			break
		}
	}
}
