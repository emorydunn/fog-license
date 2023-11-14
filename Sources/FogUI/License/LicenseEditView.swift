//
//  LicenseEditView.swift
//  License Manager
//
//  Created by Emory Dunn on 11/4/23.
//

import SwiftUI
import FogKit
import SharedModels

public struct LicenseEditView: View {

	@Environment(\.dismiss) var dismiss

	@Environment(\.client) var client

	@Binding var license: SoftwareLicense

	@State var expiryDate: Date = .now

	@State var presentError = false
	@State var error: ServerError?

	public init(_ license: Binding<SoftwareLicense>) {
		self._license = license
		self._expiryDate = State(initialValue: license.wrappedValue.expiryDate ?? .now)

	}

	public var body: some View {
		Form {
			Toggle("Active", isOn: $license.isActive)

			TextField("Activation Limit:", value: $license.activationLimit, format: .number)


			Toggle("Expiration Date:", isOn: expiryBinding)
				.padding(.top)
				.toggleStyle(.switch)

			DatePicker("Expiry Date:", selection: $expiryDate, displayedComponents: [.date])
				.disabled(license.expiryDate == nil)
				.labelsHidden()
				.datePickerStyle(.graphical)

			HStack {

				Spacer()
				Button("Cancel", action: cancelEdit)
					.keyboardShortcut(.escape)
				Button("Save", action: submitEdit)
					.keyboardShortcut(.defaultAction)
					.disabled(license.activationLimit < 1)
			}
			.padding(.top)
		}
		.padding()
		.textFieldStyle(.roundedBorder)
		.frame(width: 300)
		.navigationTitle("License \(license.code.formatted(.hexBytes))")
		.alert(isPresented: $presentError, error: error) {
			Button("OK") {
				presentError = false
			}
		}
	}

	var expiryBinding: Binding<Bool> {
		Binding {
			license.expiryDate != nil
		} set: { newValue in
			if newValue {
				license.expiryDate = expiryDate
			} else {
				license.expiryDate = nil
			}
		}
	}

	var expiryDateBinding: Binding<Date>? {
		guard let date = license.expiryDate else { return nil }

		return Binding {
			license.expiryDate ?? date
		} set: { newValue in
			license.expiryDate = newValue
		}

		//		Binding($license.expiryDate)
	}

	func cancelEdit() {
		dismiss()
	}

	func submitEdit() {
		Task {
			do {
				license = try await client.licenses.update(license)
				await MainActor.run {
					dismiss()
				}
			} catch let e as ServerError {
				error = e
				presentError = true
			} catch {
				print(error)
			}
		}
	}
}

#Preview {
	Group {
		LicenseEditView(.constant(.preview))
	}
}
