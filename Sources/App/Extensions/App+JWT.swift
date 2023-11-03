//
//  File.swift
//  
//
//  Created by Emory Dunn on 11/1/23.
//

import Foundation
import Vapor
import JWT

extension Application {
	func readJWTKeys() throws {

		let pem: String

		let workingDir = URL(filePath: directory.workingDirectory)
		let keyFile = URL(fileURLWithPath: "id_ecdsa", relativeTo: workingDir)

		do {
			pem = try String(contentsOf: keyFile)
			logger.notice("Reading ECDSA key from file")
		} catch {
			logger.notice("Generating new ECDSA key pair")
			let privateKey = P256.Signing.PrivateKey()
			pem = privateKey.pemRepresentation

			let pubFile = URL(fileURLWithPath: "id_ecdsa.pub", relativeTo: workingDir)

			try privateKey.pemRepresentation.write(to: keyFile, atomically: true, encoding: .utf8)
			try privateKey.publicKey.pemRepresentation.write(to: pubFile, atomically: true, encoding: .utf8)
		}

		let key = try ECDSAKey.private(pem: pem)

		jwt.signers.use(.es256(key: key))

	}
}
