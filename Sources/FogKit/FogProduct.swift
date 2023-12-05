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
	/// The current state of the license.
	public private(set) var activationSate = ActivatedLicense()

//	@Published
//	public private(set) var app: AppInfo
	
	/// The name of the application.
	///
	/// - Note: Updated when refreshing from the server.
	public private(set) var name: String
	
	/// The bundle identifier of the application.
	public let bundleIdentifier: String
	
	/// The app number of the application used to validate license codes.
	///
	/// - Note: Updated when refreshing from the server.
	public private(set) var appNumber: UInt8
	
	/// A boolean indicating whether the the app has been refreshed from the server. 
	public private(set) var isStale = true
	
	/// Create a new `FogProduct` using an `AppInfo` object.
	/// - Parameter app: The app to use as the basis of the product.
	public init(app: AppInfo) {
		self.name = app.name
		self.bundleIdentifier = app.bundleIdentifier
		self.appNumber = app.number
	}
	
	/// Create a new `FogProduct` by reading the specified bundle.
	///
	/// - Important: The number must contain `CFBundleIdentifier` and `CFBundleName`.
	/// - Parameters:
	///   - bundle: The Bundle to read, by default the main bundle.
	///   - appNumber: The app's number, defaults to 255.
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
	
	/// The location of the license file.
	var licenseURL: URL {
		URL(filePath: "/Users/Shared/", directoryHint: .isDirectory)
			.appending(components: name, "License.plist")
	}
	
	/// Save the activation to disk.
	public func storeActivation() throws {
		logger.log("Saving activation state to \(self.licenseURL.path)")
		// Attempt to create the directory
		try FileManager.default.createDirectory(at: licenseURL.deletingLastPathComponent(), withIntermediateDirectories: true)

		let stored = ActivatedLicense.Stored(activationSate)

		let data = try PropertyListEncoder().encode(stored)

		try data.write(to: licenseURL)
	}
	
	/// Read the activation from disk.
	/// - Parameter client: The client to use to decode the JWT token.
	public func readActivation(using client: FogClient) async {
		do {
			logger.log("Reading activation state from \(self.licenseURL.path)")
			let data = try Data(contentsOf: licenseURL)
			let stored = try PropertyListDecoder().decode(ActivatedLicense.Stored.self, from: data)

			await MainActor.run {
				self.activationSate = stored.createActivationState(with: client.signer)
			}

			logger.log("Successfully read activation from disk, setting state to \(self.activationSate)")
		} catch {
			logger.error("Could not read stored activation with error \(error.localizedDescription)")
		}
	}

	// MARK: - Server Calls
	/// Look up the application on the server and update local properties.
	/// - Parameter client: The client to use to communicate with the server.
	public func refresh(using client: FogClient) async throws {
		logger.info("Refreshing \(self.isStale ? "stale " : "")product from server.")
		let app = try await client.apps.get(bundleIdentifier: self.bundleIdentifier)

		await MainActor.run {
			self.name = app.name
			self.appNumber = app.number
			self.isStale = false
		}
	}

	
	/// Attempt to activate a license code.
	/// - Parameters:
	///   - code: The `LicenseCode` to send to the server.
	///   - client: The client to use to communicate with the server.
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

		try storeActivation()

		logger.info("Activated license with new state \(self.activationSate)")
	}
	
	/// Attempt to verify the current activation with the server.
	/// - Parameter client: The client to use to communicate with the server.
	public func verifyLicense(using client: FogClient, forced: Bool = false) async throws {
		logger.log("Verifying activation with state \(self.activationSate)")

		if forced == false {
			guard activationSate.needsVerification else {
				logger.info("Activation state \(self.activationSate) doesn't need verification.")
				return
			}
		}

		let state = try await client.licenses.activateLicense(activationSate)
		await MainActor.run {
			self.activationSate = state
		}

		try storeActivation()

		logger.info("Verified activation with new state \(self.activationSate)")
	}

	/// Attempt to reactivate this machine.
	/// - Parameter client: The client to use to communicate with the server.
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
	/// - Parameter client: The client to use to communicate with the server.
	public func deactivateMachine(using client: FogClient) async throws {
		guard
			let license = activationSate.license,
			let activation = activationSate.activation
		else {
			logger.notice("This computer is not currently activated.")
			return
		}

		logger.info("Deactivating the license on this computer.")

		try await client.licenses.deactivate(license: license.code, activation: activation)

		await MainActor.run {
			self.activationSate = ActivatedLicense(license: license/*, activation: activation*/)
		}

		try storeActivation()

		logger.info("Computer has successfully been deactivated.")
	}
	
	/// Deactivate and remove the license from the machine.
	/// - Parameter client: The client to use to communicate with the server.
	public func removeLicense(using client: FogClient) async throws {

		if activationSate.isActivated {
			logger.info("Deactivating machine and removing the license.")
			if
				let license = activationSate.license,
				let activation = activationSate.activation
			{
				try await client.licenses.deactivate(license: license.code, activation: activation)
			}

			await MainActor.run {
				activationSate = ActivatedLicense()
			}
		} else if activationSate.isLicensed {
			logger.info("Removing the current license.")

			await MainActor.run {
				activationSate = ActivatedLicense()
			}
		} else {
			logger.notice("This computer is not licensed.")
		}

		// Destroy the saved license on disk
		try FileManager.default.removeItem(at: licenseURL)
	}
}

