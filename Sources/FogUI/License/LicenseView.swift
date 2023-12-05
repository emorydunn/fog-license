//
//  LicenseView.swift
//  License Manager
//
//  Created by Emory Dunn on 11/2/23.
//

import SwiftUI
import FogKit
import SharedModels

public struct LicenseView: View {

	@Environment(\.client) var client

	@EnvironmentObject var product: FogProduct

	public init() { }

	public var body: some View {
		Group {
			if let license = product.activationSate.license {
				LicenseDetailView(license: license,
								  machineActivated: product.activationSate.isActivated,
								  useLocalIcon: false,
								  verificationExpiry: product.activationSate.activation?.expirationDate)
			} else {
				ActivateLicenseView()
			}
		}
		.toolbar {

			if product.activationSate.isLicensed {
				Menu("Manage") {
					if product.activationSate.isActivated {
						Button("Deactivate Machine", action: deactivateMachine)
					} else if product.activationSate.isLicensed {
						Button("Activate Machine", action: activateMachine)
					}

					Button("Manage Activations") {

					}
					.disabled(true)

					Divider()

					Button("Remove License", action: removeLicense)
						.enabled(product.activationSate.isLicensed)

#if DEBUG
					Divider()

					Button("Verify Activation") {
						verifyLicense(forced: false)
					}
					.disabled(!product.activationSate.needsVerification)

					Button("Really Verify Activation") {
						verifyLicense(forced: true)
					}
#endif

				}
			} else {
				Button("Buy Now") {
					NSWorkspace.shared.open(client.checkoutURL(for: product.bundleIdentifier))
				}
			}

		}

	}

	func verifyLicense(forced: Bool) {
		Task {
			try await product.verifyLicense(using: client, forced: forced)
		}
	}

	func activateMachine() {
		Task {
			try await product.reactivateLicense(using: client)
		}
	}

	func deactivateMachine() {
		Task {
			try await product.deactivateMachine(using: client)
		}
	}

	func removeLicense() {
		Task {
			try await product.removeLicense(using: client)
		}
	}

}

#Preview {
	LicenseView()
		.environmentObject(FogProduct(app: .preview))
}
