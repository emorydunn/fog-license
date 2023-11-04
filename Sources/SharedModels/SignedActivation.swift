//
//  SignedActivation.swift
//  
//
//  Created by Emory Dunn on 11/1/23.
//

import Foundation
import JWTKit

public struct SignedActivation: JWTPayload {

	// Maps the longer Swift property names to the
	// shortened keys used in the JWT payload.
	public enum CodingKeys: String, CodingKey {
		case bundleIdentifier = "sub"
		case expiration = "exp"
		case licenseCode
		case hardwareIdentifier
	}

	public var bundleIdentifier: SubjectClaim

	public var expiration: ExpirationClaim

	public var licenseCode: LicenseCode

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

