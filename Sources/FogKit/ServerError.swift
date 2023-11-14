//
//  ServerError.swift
//
//
//  Created by Emory Dunn on 11/7/23.
//

import Foundation

public struct ServerError: Error, LocalizedError, Decodable {
	//	let statusCode: Int
	public let reason: String
	public let error: Bool

	public var errorDescription: String? { reason }
}

extension ServerError {
	static let missingToken = ServerError(reason: "Response does not have an auth bearer token.", error: true)
	static let invalidLicense = ServerError(reason: "The activation is invalid.", error: true)
	static let hardwareInfo = ServerError(reason: "Could not read computer information.", error: true)
}
