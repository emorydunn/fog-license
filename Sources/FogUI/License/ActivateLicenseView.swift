//
//  ActivateLicenseView.swift
//  License Manager
//
//  Created by Emory Dunn on 10/31/23.
//

import SwiftUI
import OSLog
import SharedModels
import FogKit

fileprivate let logger = Logger(subsystem: "LicenseManagerUI", category: "ActivateLicenseView")

public struct ActivateLicenseView: View {

	@Environment(\.client) var client

//	@Environment(FogProduct.self) var product
	@EnvironmentObject var product: FogProduct

	@State var validatedCode: LicenseCode?
	@State var hardwareInfo = HardwareIdentifier()

	@State var code: LicenseCode?
	@State var email: String = ""

	@State var errorMessage: String = ""

	public init(code: LicenseCode? = nil) { 
		self.code = code
	}

	public var body: some View {
		VStack(alignment: .leading) {
			Form {
				HStack {
					ZStack {
						TextField("License:", value: $code, format: .licenseCode(.integer))
							.monospacedDigit()

						HStack(alignment: .center) {
							Spacer()

#if DEBUG
							Text(code, format: .licenseCode(.hexBytes))
								.font(.caption)
								.foregroundStyle(.secondary)
#endif

							if code == nil {
								Image(systemName: "circle")
									.opacity(0)
							} else if validatedCode != nil {
								Image(systemName: "checkmark.circle")
									.foregroundStyle(.green)
									.help("License code is valid.")
							} else {
								Image(systemName: "minus.circle")
									.foregroundStyle(.red)
									.help("License code does not match \(product.name).")
							}
						}
						.padding(.trailing, 8)
						.monospaced()
					}

					Button("Activate") {
						guard
							let validatedCode
						else { return }

						Task {
							do {
								try await product.activateLicense(validatedCode, using: client)
							} catch {
								errorMessage = error.localizedDescription
								print(error)
							}
						}
					}
					.keyboardShortcut(.defaultAction)
					.disabled(validatedCode == nil)
					.disabled(hardwareInfo == nil)

				}

				Text(errorMessage)
					.font(.caption)
					.foregroundStyle(.secondary)
					.frame(height: 8)

			}
			.textFieldStyle(.roundedBorder)
			.onChange(of: code) { _ in
				validateCode()
			}

			Divider()
				.padding(.bottom, 8)


			HStack {
				if let hardwareInfo {
					Grid {
						GridRow {
							Text("Name:")
								.gridColumnAlignment(.trailing)
							Text(hardwareInfo.computerName)
								.textSelection(.enabled)
								.gridColumnAlignment(.leading)
						}

						GridRow {
							Text("OS Version:")
							Text(hardwareInfo.osVersion)
								.textSelection(.enabled)
						}

						GridRow {
							Text("Model:")
							Text(hardwareInfo.computerModel)
								.textSelection(.enabled)
						}

						GridRow {
							Text("Computer ID:")
							Text(verbatim: hardwareInfo.hashDescription(truncate: true))
								.textSelection(.enabled)
								.monospaced()
						}
					}
				} else {
					Text("Could not determine hardware")
				}

				Spacer()
			}
			.padding([.horizontal, .bottom])

			Text("Basic information about your computer is collected to help manage your licenses and to help us better understand our users. It is never shared with third parties.")
				.font(.caption2)
				.foregroundStyle(.secondary)
				.frame(width: 400, height: 50)
				.multilineTextAlignment(.leading)
				.padding(.horizontal)

//			HStack {
//				Button("Buy Now") {
//					NSWorkspace.shared.open(client.checkoutURL(for: product.bundleIdentifier))
//				}
//			}

		}
		.padding()
		.onAppear(perform: validateCode)
	}

	func validateCode() {

		guard let code else {
			validatedCode = nil
			return
		}

		//		let license = LicenseCode(integerLiteral: code)
		let codeIsValid = code.isValid(for: product.appNumber)

		logger.log("License code \(code.formatted(.integer)) \(codeIsValid ? "is" : "is not") valid for app \(product.name)")

		if codeIsValid {
			validatedCode = code
			errorMessage = ""
		} else {
			validatedCode = nil
			errorMessage = "Not a valid \(product.name) license code."
		}
	}
}

#Preview {
	ActivateLicenseView(code: 123456)
//		.environment(FogProduct(app: .preview))
		.environmentObject(FogProduct(app: .preview))
//		.environment(LicenseManager(app: .preview, activation: .inactive))
}
