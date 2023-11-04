//
//  ComputerInfo.swift
//
//
//  Created by Emory Dunn on 10/23/23.
//

import Foundation
import Fluent
import Vapor

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

	static func decode(request req: Request, updatingExisting update: Bool, on db: Database) async throws -> ComputerInfo {
		// Decode the hardware ID from the body
		let hardwareIdentifier: String = try req.content.get(at: "hardwareIdentifier")

		// Look up the ID, if there isn't a machine decode the full body
		guard let info = try await find(hardwareIdentifier: hardwareIdentifier, on: db) else {
			return try req.content.decode(ComputerInfo.self)
		}

		// If updates are requested, attempt to decode the full body
		// and update the properties, otherwise skip
		if update, let computer = try? req.content.decode(ComputerInfo.self) {
			info.friendlyName = computer.friendlyName
			info.model = computer.model
			info.osVersion = computer.osVersion
		}

		return info
	}
}

