//
//  AppController.swift
//
//
//  Created by Emory Dunn on 11/7/23.
//

import Foundation
import OSLog
import SharedModels
import CoreGraphics

fileprivate let logger = Logger(subsystem: "FogKit", category: "AppController")

public struct AppController: EndpointController {
	let client: FogClient

	let endpointURL: URL

	init(client: FogClient) {
		logger.debug("Created AppController")
		self.client = client
		self.endpointURL = client.endpointURL.appending(component: "apps")
	}

	/// Return a list of applications from the server.
	/// - Returns: A sorted array of `AppInfo` objects.
	public func list() async throws -> [AppInfo] {
		logger.info("Listing applications.")
		let request = URLRequest(url: endpointURL)

		let (apps, _) = try await session.data(for: request, decoding: [AppInfo].self, expectedCodes: 200, with: decoder)

		logger.log("Decoded \(apps.count) apps")

		return apps.sorted()
	}

	/// Retrieve an application based on its bundle identifier.
	/// - Parameter bundleIdentifier: The applications' bundle identifier.
	/// - Returns: An `AppInfo` if the application exists.
	public func get(bundleIdentifier: String) async throws -> AppInfo {
		logger.info("Getting application with bundle identifier \(bundleIdentifier)")
		let request = URLRequest(url: endpointURL.appending(component: bundleIdentifier))

		let (newModel, _) = try await session.data(for: request, 
												   decoding: AppInfo.self,
												   expectedCodes: 200,
												   with: decoder)

		logger.log("Fetched app \(newModel.name)")

		return newModel
	}

	/// Reload an `AppInfo` model by pulling it down from the server.
	/// - Parameter bundleIdentifier: The application to reload.
	/// - Returns: An `AppInfo` if the application exists.
	public func get(app: AppInfo) async throws -> AppInfo {
		try await get(bundleIdentifier: app.bundleIdentifier)
	}

	public func icon(at iconPath: String) async throws -> CGImage? {
		let iconURL = client.server.appending(components: iconPath)
		logger.log("Downloading icon from \(iconURL.path(percentEncoded: false))")

		let request = URLRequest(url: iconURL)

		let (data, response) = try await session.data(for: request)

		guard let response = response as? HTTPURLResponse else { fatalError("Should be HTTP response") }

		logger.log("\(response.statusCode) \(request.url!.relativePath)")

		guard let provider = CGDataProvider(data: data as CFData) else { return nil }

		return CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)

	}

	/// Create a new application.
	/// - Parameter app: The `AppInfo` object to upload.
	/// - Returns: The saved `AppInfo` from the server.
	public func create(_ app: AppInfo) async throws -> AppInfo {
		logger.info("Creating application with bundle identifier \(app.bundleIdentifier)")

		var request = URLRequest(url: endpointURL)
		request.httpMethod = "POST"
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

		request.httpBody = try encoder.encode(app)

		let (newModel, _) = try await session.data(for: request, 
												   decoding: AppInfo.self,
												   expectedCodes: 200,
												   with: decoder)

		logger.log("Created app \(newModel.name)")

		return newModel
	}

	/// Update an existing application.
	/// - Parameter app: The `AppInfo` object to upload.
	/// - Returns: The saved `AppInfo` from the server.
	public func update(_ app: AppInfo) async throws -> AppInfo {
		logger.info("Updating application with bundle identifier \(app.bundleIdentifier)")

		var request = URLRequest(url: endpointURL.appending(component: app.bundleIdentifier))
		request.httpMethod = "PUT"
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

		request.httpBody = try encoder.encode(app)

		let (newModel, _) = try await session.data(for: request, 
												   decoding: AppInfo.self,
												   expectedCodes: 200,
												   with: decoder)

		logger.log("Created app \(newModel.name)")

		return newModel
	}

	/// Delete an application.
	///
	/// - Warning: There be dragons!
	func delete() {
		
	}
}
