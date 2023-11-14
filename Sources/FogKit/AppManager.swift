//
//  AppManager.swift
//  License Manager
//
//  Created by Emory Dunn on 11/9/23.
//

import Foundation
@_exported import SharedModels
import CoreGraphics
import OSLog

fileprivate let logger = Logger()

@available(macOS 14.0, *)
@Observable
public class AppManager {

	public var applications: [AppInfo] = []

	public var iconCache: [String: CGImage] = [:]

	public init() { }

	public subscript (bundleIdentifier: String) -> AppInfo {
		applications.first(where: { $0.bundleIdentifier == bundleIdentifier })!
	}

	public func refreshApps(using client: FogClient) {
		Task {
			applications = try await client.apps.list()
		}
	}

	public func icon(for app: AppInfo, using client: FogClient) -> CGImage? {
		logger.debug("Downloading icon for app \(app.bundleIdentifier)")
		return icon(at: app.iconPath, bundleIdentifier: app.bundleIdentifier, using: client)
	}

	public func icon(for license: SoftwareLicense, using client: FogClient) -> CGImage? {
		logger.debug("Downloading icon for license \(license.bundleIdentifier)")
		return icon(at: license.iconPath, bundleIdentifier: license.bundleIdentifier, using: client)
	}

	public func icon(at iconPath: String, bundleIdentifier: String, using client: FogClient) -> CGImage? {
		// Provide a cached icon if possible
		if let cached = iconCache[bundleIdentifier] {
			logger.info("Returning cached icon for \(bundleIdentifier)")
			return cached
		}

		// Otherwise fetch the icon and return nil
		// When the icon has downloaded the cache will
		// be updated causing observers to get the icon again
		Task.detached(priority: .background) {
			logger.log("Downloading icon for \(bundleIdentifier) from \(iconPath)")
			guard let image = try await client.apps.icon(at: iconPath) else { return }

			await MainActor.run {
				self.iconCache[bundleIdentifier] = image
			}
		}
		return nil
	}

	public func submitEdit(for app: AppInfo, newApp: Bool, using client: FogClient) async throws {
		if newApp {
			_ = try await client.apps.create(app)
		} else {
			_ = try await client.apps.update(app)
		}
	}

}
