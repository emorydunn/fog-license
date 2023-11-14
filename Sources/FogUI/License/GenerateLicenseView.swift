//
//  GenerateLicenseView.swift
//  License Manager
//
//  Created by Emory Dunn on 11/2/23.
//

import SwiftUI
import SharedModels

public struct GenerateLicenseView: View {

	@Environment(\.client) var client

	let app: AppInfo

	@State fileprivate var email: String = ""

	public init(app: AppInfo) {
		self.app = app
	}

	public var body: some View {
		Form {
			TextField("Email Address:", text: $email)

			Button("Generate License") {
				
			}
		}
	}
}

#Preview {
	GenerateLicenseView(app: .preview)
}
