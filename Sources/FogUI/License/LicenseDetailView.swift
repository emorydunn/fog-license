//
//  LicenseDetailView.swift
//  License Manager
//
//  Created by Emory Dunn on 11/2/23.
//

import SwiftUI
import SharedModels

public struct LicenseDetailView: View {

	@Environment(\.client) var client

	let license: SoftwareLicense

	let machineActivated: Bool

	let useLocalIcon: Bool

	let verificationExpiry: Date?

	public init(license: SoftwareLicense,
				machineActivated: Bool,
				useLocalIcon: Bool,
				verificationExpiry: Date?) {
		self.license = license
		self.machineActivated = machineActivated
		self.useLocalIcon = useLocalIcon
		self.verificationExpiry = verificationExpiry
	}

	public var body: some View {
		VStack(alignment: .leading) {
			header
				.padding([.bottom, .leading])

			GroupBox("This copy is registered to:") {
				HStack {
					Grid {

						GridRow {
							Text("Name:")
								.gridColumnAlignment(.trailing)
							Text(license.customerName)
								.gridColumnAlignment(.leading)
						}

						GridRow {
							Text("Email:")
								.gridColumnAlignment(.trailing)
							Text(license.customerEmail)
						}

						GridRow {
							Text("License Code:")
								.gridColumnAlignment(.trailing)

							Text(license.code, format: .licenseCode(.integer))

						}

						GridRow {
							Text("Activations:")
								.gridColumnAlignment(.trailing)

							Text(license.activationCount, format: .number) +
							Text("/") +
							Text(license.activationLimit, format: .number)
						}

						if let expiryDate = license.expiryDate {
							GridRow {
								Text("Updates Through:")
									.gridColumnAlignment(.trailing)
								Text(expiryDate, format: .dateTime.year().month().day())
							}
						}

						#if DEBUG
						if let verificationExpiry {
							GridRow {
								Text("Verification Expiry:")
									.gridColumnAlignment(.trailing)
								Text(verificationExpiry, format: .dateTime.year().month().day().hour().minute().second())
							}
						}
						#endif

					}
					.padding(.leading)

					Spacer()

				}
			}

		}

	}

	var header: some View {
		HStack {
			AppIcon(remotePath: useLocalIcon ? nil : license.iconPath)
				.frame(width: 64, height: 64)

			VStack(alignment: .leading) {
				Text("\(license.name) is Registered")
					.font(.headline)
					.padding(.bottom, 8)

				switch (license.isActive, machineActivated) {
				case (true, true):
					Text("this computer is activated")
				case (true, false):
					Text("This computer is deactivated")
				default:
					Text("This license is inactive")
				}

			}
		}
	}

}

#if DEBUG
#Preview {
	LicenseDetailView(license: .preview, machineActivated: true, useLocalIcon: true, verificationExpiry: Date())
}
#endif
