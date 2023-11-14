//
//  SoftwareLicense.swift
//  
//
//  Created by Emory Dunn on 10/30/23.
//

import Foundation

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

public enum ActivatedLicense: Codable {
	case activated(license: SoftwareLicense, activation: SignedVerification, token: String)
	case licensed(license: SoftwareLicense, activation: SignedVerification)
	case inactive

	/// Whether the machine is activated.
	public var isActivated: Bool {
		switch self {
		case .activated:
			return true
		case .licensed:
			return false
		case .inactive:
			return false
		}
	}

	/// Whether the machine is licensed.
	public var isLicensed: Bool {
		switch self {
		case .activated:
			return true
		case .licensed:
			return true
		case .inactive:
			return false
		}
	}

	public var license: SoftwareLicense? {
		switch self {
		case .activated(let license, _, _):
			return license
		case .licensed(let license, _):
			return license
		case .inactive:
			return nil
		}
	}

	public var activation: SignedVerification? {
		switch self {
		case .activated(_, let activation, _):
			return activation
		case .licensed(_, let activation):
			return activation
		case .inactive:
			return nil
		}
	}
	
	/// Determine whether the activation needs to be verified with the server.
	public var needsVerification: Bool {
		switch self {
		case .activated(_, let activation, _):
			return activation.isExpired
		case .licensed:
			return false
		case .inactive:
			return false
		}
	}

}

extension ActivatedLicense: CustomStringConvertible {
	public var description: String {
		switch self {
		case .activated:
			return "Activated License"
		case .licensed:
			return "Licensed"
		case .inactive:
			return "Inactive"
		}
	}
}
