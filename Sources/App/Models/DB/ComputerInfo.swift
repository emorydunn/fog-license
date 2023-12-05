//
//  ComputerInfo.swift
//
//
//  Created by Emory Dunn on 10/23/23.
//

import Foundation
import Fluent
import Vapor
import SharedModels

final class ComputerInfo: Model {

	static var schema = "computer_info"
	
	@ID(key: .id)
	var id: UUID?

	@Field(key: "hardware_id")
	var hardwareIdentifier: String

	@OptionalField(key: "friendly_name")
	var friendlyName: String?

	@Field(key: "model")
	var model: String

	@Field(key: "os_version")
	var osVersion: String

	@Children(for: \.$computer)
	var activations: [Activation]

	init() {}
	
	init(id: UUID? = nil, hardwareIdentifier: String, friendlyName: String? = nil, model: String, osVersion: String) {
		self.id = id
		self.hardwareIdentifier = hardwareIdentifier
		self.friendlyName = friendlyName
		self.model = model
		self.osVersion = osVersion
	}


	static func find(hardwareIdentifier: String, on db: Database) async throws -> ComputerInfo? {
		return try await ComputerInfo.query(on: db)
			.filter(\.$hardwareIdentifier == hardwareIdentifier)
			.first()
	}

	static func find(hardwareIdentifier: String, on db: Database, orDecode req: Request) async throws -> ComputerInfo {
		if let info = try await find(hardwareIdentifier: hardwareIdentifier, on: db) {
			return info
		}

		return try req.content.decode(ComputerInfo.self)
	}


	static func update(computer: ComputerInfo, on db: Database) async throws -> ComputerInfo {
		guard let info = try await find(hardwareIdentifier: computer.hardwareIdentifier, on: db) else {
			return computer
		}

		info.friendlyName = computer.friendlyName
		info.model = computer.model
		info.osVersion = computer.osVersion

		return info
	}

	static func decodeActivationRequest(from req: Request, updatingExisting update: Bool, on db: Database) async throws -> ComputerInfo {

		req.logger.info("Decoding computer hardware identifier from request body")

		// Decode the hardware ID from the body
		let hardwareIdentifier: String = try req.content.get(at: "hardwareIdentifier")

		// Look up the ID, if there isn't a machine decode the full body
		guard let info = try await find(hardwareIdentifier: hardwareIdentifier, on: db) else {
			req.logger.info("Couldn't find computer with id \(hardwareIdentifier), creating new computer from body.")
			let info = try req.content.decode(SoftwareLicense.ActivationRequest.self)

			return ComputerInfo(hardwareIdentifier: info.hardwareIdentifier,
								friendlyName: info.friendlyName,
								model: info.model,
								osVersion: info.osVersion)
		}

		guard update else { return info }

		req.logger.info("Updating info of \(info.friendlyName ?? info.model) from body.")

		do {

			// If updates are requested, attempt to decode the full body
			// and update the properties, otherwise skip
			let computer = try req.content.decode(SoftwareLicense.ActivationRequest.self)
			info.friendlyName = computer.friendlyName
			info.model = computer.model
			info.osVersion = computer.osVersion

		} catch {
			req.logger.warning("Failed to decode computer from request body, not updating information")
			req.logger.warning("\(error.localizedDescription)")
		}

		return info
	}
}

