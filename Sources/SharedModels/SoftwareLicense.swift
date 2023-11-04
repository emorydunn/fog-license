//
//  SoftwareLicense.swift
//  
//
//  Created by Emory Dunn on 10/30/23.
//

import Foundation

public struct SoftwareLicense: Codable, Identifiable, Hashable {
	public init(code: LicenseCode, name: String, bundleIdentifier: String, customerName: String, customerEmail: String, date: Date, expiryDate: Date? = nil, isActive: Bool, activationLimit: Int, activationCount: Int) {
		self.code = code
		self.name = name
		self.bundleIdentifier = bundleIdentifier
		self.customerName = customerName
		self.customerEmail = customerEmail
		self.date = date
		self.expiryDate = expiryDate
		self.isActive = isActive
		self.activationLimit = activationLimit
		self.activationCount = activationCount
	}

	public var id: UInt32 { code.number }

	public let code: LicenseCode
	public let name: String
	public let bundleIdentifier: String

	public let customerName: String
	public let customerEmail: String

	public let date: Date
	public var expiryDate: Date?

	public var isActive: Bool
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
		public let friendlyName: String
		public let model: String
		public let osVersion: String

		public init(bundleIdentifier: String, hardwareIdentifier: String, computerName: String, computerModel: String, osVersion: String) {
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

		public  init(bundleIdentifier: String, customerEmail: String, date: Date? = nil, isActive: Bool? = nil, expiryDate: Date? = nil) {
			self.bundleIdentifier = bundleIdentifier
			self.customerEmail = customerEmail
			self.date = date
			self.isActive = isActive
			self.expiryDate = expiryDate
		}
	}


}

public enum ActivatedLicense {
	case activated(license: SoftwareLicense, activation: SignedActivation)
	case licensed(license: SoftwareLicense)
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

}
