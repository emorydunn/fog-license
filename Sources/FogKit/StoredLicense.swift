//
//  StoredActivation.swift
//  
//
//  Created by Emory Dunn on 12/4/23.
//

import Foundation
import JWTKit

extension ActivatedLicense {

	/// A representation of an activation suitable for persisting on disk.
	///
	/// This is the same information, a `SoftwareLicense` and `SignedVerification` token sent
	/// by the server when activating a `LicenseCode`.  Use this object to restore the activation state of an application.
	public struct Stored: Codable {
		private let license: SoftwareLicense?
		private let token: String?
		
		/// Create a new instance that can be saved to disk.
		/// - Parameter activationState: The `ActivatedLicense` to persist.
		public init(_ activationState: ActivatedLicense) {
			self.license = activationState.license
			self.token = activationState.token
		}
		
		/// Recreate `ActivatedLicense` from a stored license.
		/// - Parameter signer: The signer used to verify the token.
		/// - Returns: An `ActivatedLicense`.
		public func createActivationState(with signer: JWTSigner) -> ActivatedLicense {
			// If there's a token create an activated license
			if let license, let token {
				do {
					// Attempt to decode the token. 
					// We're not verifying the token as that will deactivate a machine who's
					// token expired before reading. We want to keep the previous activation state
					// and let the application handle verifying the token on its own.
					let activation = try signer.unverified(token, as: SignedVerification.self)
					return ActivatedLicense(license: license, activation: activation, token: token)
				} catch {
					return ActivatedLicense(license: license)
				}
			}

			// No token, deactivated license
			if let license {
				return ActivatedLicense(license: license)
			}

			// Not even that? Inactive license
			return ActivatedLicense()
		}
	}
}
