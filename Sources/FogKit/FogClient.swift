//
//  FogClient.swift
//
//
//  Created by Emory Dunn on 11/6/23.
//

import Foundation
import OSLog
import JWTKit
import SharedModels

fileprivate let logger = Logger(subsystem: "FogKit", category: "FogClient")

/// The primary interface for accessing the licensing server. 
///
/// Each model type (App, License, etc.) is presented via a separate controller, grouping
/// methods for that model.
public class FogClient {

	public enum Errors: Error {
		case missingPEMFile
	}

	let server: URL

	let signer: JWTSigner

	var session: URLSession = URLSession.shared

	let endpointURL: URL

	lazy var decoder: JSONDecoder = {
		let coder = JSONDecoder()

		coder.dateDecodingStrategy = .iso8601

		return coder
	}()

	lazy var encoder: JSONEncoder = {
		let coder = JSONEncoder()

		coder.dateEncodingStrategy = .iso8601

		return coder
	}()
	
	/// Create a new client for a licensing server.
	///
	/// - Parameters:
	///   - server: The server's URL.
	///   - signer: A signer initialized with the public key for the server.
	public init(server: URL, signer: JWTSigner) {
		logger.info("Creating FogClient for server \(server.absoluteString, privacy: .sensitive) signed with \(signer.algorithm.name, privacy: .public)")
		self.server = server
		self.signer = signer
		self.endpointURL = server.appending(components: "api", "v1")
	}
	
	/// Create a new client for a licensing server.
	///
	/// - Warning: If the key can not be read or is invalid the application will crash.
	/// - Parameters:
	///   - server: The server's URL.
	///   - pemURL: The URL of a file containing the public key for the server.
	public convenience init(server: URL, pemURL: URL) {
		logger.debug("Reading public key from \(pemURL.lastPathComponent)")
		do {
			let pem = try String(contentsOf: pemURL, encoding: .utf8)
			let key = try ECDSAKey.public(pem: pem)

			self.init(server: server, signer: .es256(key: key))
		} catch {
			preconditionFailure(error.localizedDescription)
		}
	}
	
	/// Create a new client for a licensing server.
	///
	/// - Warning: If the key file can not be found the application will crash.
	/// - Parameters:
	///   - server: The server's URL.
	///   - bundle: The bundle containing the PEM file.
	///   - name: The name of the PEM file.
	///   - ext: The extension of the PEM file.
	public convenience init(server: URL, bundle: Bundle = .main, forResource name: String = "id_ecdsa",
							withExtension ext: String = "pub") {
		
		logger.debug("Reading public key from bundle \(bundle.bundlePath)")
		guard let url = bundle.url(forResource: name, withExtension: ext) else {
			preconditionFailure("'\(name).\(ext)' is missing from bundle.")
		}

		self.init(server: server, pemURL: url)
	}

	public func checkoutURL(for bundleIdentifier: String) -> URL {
		server.appending(components: "checkout", bundleIdentifier)
	}

	// MARK: - Controllers
	public lazy var apps: AppController = {
		AppController(client: self)
	}()

	public lazy var licenses: LicenseController = {
		LicenseController(client: self)
	}()

}
