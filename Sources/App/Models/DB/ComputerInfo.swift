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
		let computer = try req.content.decode(ComputerInfo.self)

		guard let info = try await find(hardwareIdentifier: computer.hardwareIdentifier, on: db) else {
			return computer
		}

		if update {
			info.friendlyName = computer.friendlyName
			info.model = computer.model
			info.osVersion = computer.osVersion
		}

		return info
	}
}

