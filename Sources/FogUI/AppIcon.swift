//
//  AppIcon.swift
//  License Manager
//
//  Created by Emory Dunn on 11/9/23.
//

import SwiftUI
import CoreGraphics
import FogKit

public struct AppIcon: View {

	@Environment(\.client) var client

	@State var icon: CGImage?

	let remotePath: String?

	public init(remotePath: String? = nil) {
		self.remotePath = remotePath
	}

	public var body: some View {
		appIcon
			.resizable()
			.onAppear(perform: loadIcon)
	}

	var appIcon: Image {
		if let icon {
			return Image(icon, scale: 2, label: Text("Application Icon"))
		} else if let appIcon = NSImage(named: "NSApplicationIcon") {
			return Image(nsImage: appIcon)
		} else {
			return Image(systemName: "app")
		}
	}

	func loadIcon() {
		guard let remotePath else { return }
		Task {
			self.icon = try await client.apps.icon(at: remotePath)
		}
	}

}

#Preview {
	AppIcon()
}
