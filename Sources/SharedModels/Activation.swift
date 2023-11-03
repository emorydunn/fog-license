//
//  File.swift
//  
//
//  Created by Emory Dunn on 11/1/23.
//

import Foundation

struct Activation: Codable {
	// License Info
	let code: LicenseCode
	
	let expiryDate: Date?


	// Customer Info
	let customerName: String
	let customerEmail: String

	// Activation Info

}
