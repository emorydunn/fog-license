//
//  HTTP+Bearer.swift
//
//
//  Created by Emory Dunn on 11/7/23.
//

import Foundation

extension HTTPURLResponse {
	var bearerAuthorization: String? {
		guard let string = value(forHTTPHeaderField: "authorization") else {
			return nil
		}

		let headerParts = string.split(separator: " ")
		guard headerParts.count == 2 else {
			return nil
		}
		guard headerParts[0].lowercased() == "bearer" else {
			return nil
		}
		return String(headerParts[1])
	}
}
