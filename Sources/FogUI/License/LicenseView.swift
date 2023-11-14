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

//	@Environment(FogProduct.self) var product
	@EnvironmentObject var product: FogProduct

	public init() { }

	public var body: some View {
		Group {
			if let license = product.activationSate.license {
				LicenseDetailView(license: license,
								  machineActivated: product.activationSate.isActivated,
								  useLocalIcon: false)
			} else {
				ActivateLicenseView()
			}
		}
		.toolbar {
			ToolbarItem {
				Menu {
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

				} label: {
					Text("Manage")
				}
			}
		}

	}

	func activateMachine() {
		Task {
			try await product.reactivateLicense(using: client)
		}
	}

	func deactivateMachine() {
//		guard case .activated(let license, let activation) = manager.activation else {
//			return
//		}

		Task {
//			try await client.deactivate(license: license.code, activation: activation)
//			manager.activation = .licensed(license: license, activation: activation)
			try await product.deactivateMachine(using: client)
		}
	}

	func removeLicense() {
		Task {
			try await product.removeLicense(using: client)
//			switch manager.activation {
//			case .activated(let license, let activation):
//				try await client.deactivate(license: license.code, activation: activation)
//				manager.activation = .inactive
//			case .licensed:
//				manager.activation = .inactive
//			case .inactive:
//				break
//			}
		}
	}

}

#Preview {
//	LicenseView(app: .preview, license: .inactive)
	LicenseView()
		.environmentObject(FogProduct(app: .preview))
//		.environment(LicenseManager(app: .preview, activation: .inactive))
}
