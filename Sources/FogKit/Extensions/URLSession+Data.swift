//
//  File.swift
//  
//
//  Created by Emory Dunn on 11/7/23.
//

import Foundation
import OSLog

fileprivate let logger = Logger()

extension URLSession {

	func data<T: Decodable>(for request: URLRequest,  decoding type: T.Type, expectedCodes: Int..., with decoder: JSONDecoder) async throws -> (T, HTTPURLResponse) {
		let (data, response) = try await data(for: request)

		guard let response = response as? HTTPURLResponse else { fatalError("Should be HTTP response") }
		logger.log("\(response.statusCode) \(request.url!.relativePath)")

		if expectedCodes.contains(response.statusCode) {
			logger.debug("Server returned expected status from \(expectedCodes)")

			guard let object = try? decoder.decode(T.self, from: data) else {
				throw ServerError(reason: "Error decoding server response", error: true)
			}

			return (object, response)
		}

		logger.warning("Server returned unexpected status, decoding error from body")

		guard let error = try? decoder.decode(ServerError.self, from: data) else {
			throw ServerError(reason: "Unknown Error", error: true)
		}

		throw error
	}

}
