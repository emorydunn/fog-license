//
//  SignedActivation.swift
//  
//
//  Created by Emory Dunn on 11/1/23.
//

import Foundation
import JWTKit

public struct SignedVerification: JWTPayload, Equatable {

	// Maps the longer Swift property names to the
	// shortened keys used in the JWT payload.
	public enum CodingKeys: String, CodingKey {
		case bundleIdentifier = "sub"
		case expiration = "exp"
		case licenseCode
		case hardwareIdentifier
	}
	
	/// The Bundle Identifier of the application.
	public var bundleIdentifier: SubjectClaim
	
	/// The date at which _this_ verification expires and the code will need to be
	/// verified again with the server. This is not any dates associated with the Activation.
	public var expiration: ExpirationClaim
	
	/// The license code associated with the activation.
	public var licenseCode: LicenseCode
	
	/// The Hardware Identifier of the machine associated with the activation.
	public var hardwareIdentifier: String

	public init(bundleIdentifier: String, expiration: Date, licenseCode: LicenseCode, hardwareIdentifier: String) {
		self.bundleIdentifier = .init(value: bundleIdentifier)
		self.expiration = .init(value: expiration)
		self.licenseCode = licenseCode
		self.hardwareIdentifier = hardwareIdentifier
	}

	// Run any additional verification logic beyond
	// signature verification here.
	// Since we have an ExpirationClaim, we will
	// call its verify method.
	public func verify(using signer: JWTSigner) throws {
		try self.expiration.verifyNotExpired()
	}
	
	/// Verify whether the expiration has expired or not.
	public var isExpired: Bool {
		do {
			try expiration.verifyNotExpired()
			return false
		} catch {
			return true
		}
	}
	
	/// The date at which this verification will expire.
	public var expirationDate: Date {
		expiration.value
	}
}

struct SignedTrial: JWTPayload {

	// Maps the longer Swift property names to the
	// shortened keys used in the JWT payload.
	enum CodingKeys: String, CodingKey {
		case bundleIdentifier = "sub"
		case expiration = "exp"
	}

	var bundleIdentifier: SubjectClaim

	var expiration: ExpirationClaim

	// Run any additional verification logic beyond
	// signature verification here.
	// Since we have an ExpirationClaim, we will
	// call its verify method.
	func verify(using signer: JWTSigner) throws {
		try self.expiration.verifyNotExpired()
	}
}

