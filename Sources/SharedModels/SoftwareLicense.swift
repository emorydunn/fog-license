//
//  SoftwareLicense.swift
//  
//
//  Created by Emory Dunn on 10/30/23.
//

import Foundation
import JWTKit

/// The `SoftwareLicense` provides a reference to all of the metadata related to a license code.
///
/// The properties include customer info, expiration dates, subscription status, and activation limits.
/// Any mutable property represents a value that can be modified and sent back to the server to update
/// the database.
///
/// This information can be shown to a user to inform them of the status of a license. When used in this context
/// the data should be treated as a cache, as the server state may differ, for instance in the number of activations.
public struct SoftwareLicense: Codable, Identifiable, Hashable {
	public init(code: LicenseCode, 
				name: String,
				bundleIdentifier: String,
				customerName: String,
				customerEmail: String,
				activationDate: Date,
				expiryDate: Date? = nil,
				isActive: Bool,
				hasSubscription: Bool,
				activationLimit: Int,
				activationCount: Int) {
		self.code = code
		self.name = name
		self.bundleIdentifier = bundleIdentifier
		self.customerName = customerName
		self.customerEmail = customerEmail
		self.activationDate = activationDate
		self.expiryDate = expiryDate
		self.isActive = isActive
		self.isSubscribed = hasSubscription
		self.activationLimit = activationLimit
		self.activationCount = activationCount
	}

	public var id: UInt32 { code.number }

	public let code: LicenseCode
	public let name: String
	public let bundleIdentifier: String

	public let customerName: String
	public let customerEmail: String

	public let activationDate: Date
	public var expiryDate: Date?

	public var isActive: Bool
	public var isSubscribed: Bool

	public var activationLimit: Int
	public let activationCount: Int

	public var iconPath: String {
		"/images/\(bundleIdentifier).png"
	}

}

extension SoftwareLicense {
	public struct ActivationRequest: Codable {
		public let bundleIdentifier: String
		public let hardwareIdentifier: String
		public let friendlyName: String?
		public let model: String?
		public let osVersion: String?

		public init(bundleIdentifier: String, hardwareIdentifier: String, computerName: String? = nil, computerModel: String? = nil, osVersion: String? = nil) {
			self.bundleIdentifier = bundleIdentifier
			self.hardwareIdentifier = hardwareIdentifier
			self.friendlyName = computerName
			self.model = computerModel
			self.osVersion = osVersion
		}
	}

	public struct Generate: Codable {
		public let bundleIdentifier: String
		public var customerEmail: String
		public var date: Date?
		public var isActive: Bool?
		public var expiryDate: Date? = nil

		public init(bundleIdentifier: String, customerEmail: String, date: Date? = nil, isActive: Bool? = nil, expiryDate: Date? = nil) {
			self.bundleIdentifier = bundleIdentifier
			self.customerEmail = customerEmail
			self.date = date
			self.isActive = isActive
			self.expiryDate = expiryDate
		}
	}

}

/// Represents the state of a license activation.
public struct ActivatedLicense {

	public let license: SoftwareLicense?
	public let activation: SignedVerification?
	public let token: String?
	
	/// Create an activated license.
	/// - Parameters:
	///   - license: The license for the activation.
	///   - activation: The activation from the server
	///   - token: The JWT token for the activation.
	public init(license: SoftwareLicense, activation: SignedVerification, token: String) {
		self.license = license
		self.activation = activation
		self.token = token
	}
	
	/// Create a licensed, but deactivated, license.
	/// - Parameter license: The license for the activation.
	public init(license: SoftwareLicense) {
		self.license = license
		self.activation = nil
		self.token = nil
	}
	
	/// Create an inactive license. 
	public init() {
		self.license = nil
		self.activation = nil
		self.token = nil
	}

	/// Whether the machine is activated.
	public var isActivated: Bool {
		activation != nil
	}

	/// Whether the machine is licensed.
	public var isLicensed: Bool {
		license != nil
	}

	/// Determine whether the activation needs to be verified with the server.
	public var needsVerification: Bool {

		// If the application isn't licensed there's nothing to verify
		guard isLicensed else { return false }

		//
		guard let activation else {
			return false
		}

		return activation.isExpired
	}

}

extension ActivatedLicense: CustomStringConvertible {
	public var description: String {
		if isActivated {
			return "Activated License (\(activation!.expirationDate))"
		} else if isLicensed {
			return "Licensed"
		}

		return "Inactive"
	}
}
