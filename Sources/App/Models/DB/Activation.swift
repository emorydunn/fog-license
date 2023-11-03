//
//  Activation.swift
//
//
//  Created by Emory Dunn on 10/23/23.
//

import Foundation
import Fluent
import Vapor

final class Activation: Model, Content {
	static let schema = "activation"

	@ID(key: .id)
	var id: UUID?

	@Timestamp(key: "first_activation", on: .create)
	var firstActivation: Date?

	@Timestamp(key: "deactivated_date", on: .delete)
	var deactivatedDate: Date?

	@Timestamp(key: "last_verified", on: .update)
	var lastVerified: Date?

	@Parent(key: "license_id")
	var license: LicenseModel

	@Parent(key: "computer_id")
	var computer: ComputerInfo

	@Field(key: "verification_count")
	var verificationCount: Int

	init(firstActivation: Date) {
		self.firstActivation = firstActivation
	}
	
	/// Find an `Activation`, if it exists, for the given license and computer.
	/// - Parameters:
	///   - license: The ID of the `LicenseModel`.
	///   - computer: The ID of the `ComputerInfo`.
	///   - db: The `Database` to query.
	/// - Returns: An `Activation` if found.
	static func find(license: LicenseModel.IDValue, computer: ComputerInfo.IDValue, on db: Database) async throws -> Activation? {
		return try await Activation.query(on: db)
			.group(.and, { group in
				group.filter(Activation.self, \.$license.$id == license)
				group.filter(Activation.self, \.$computer.$id == computer)
			})
			.withDeleted()
			.first()
	}

	/// Find an `Activation`, or create one, for the given license and computer.
	/// - Parameters:
	///   - license: The ID of the `LicenseModel`.
	///   - computer: The ID of the `ComputerInfo`.
	///   - db: The `Database` to query.
	/// - Returns: An `Activation`.
	static func find(license: LicenseModel.IDValue, computer: ComputerInfo.IDValue, on db: Database) async throws -> Activation {
		if let activation = try await find(license: license,
											computer: computer,
										   on: db) {

			return activation
		}

		let activation = Activation()

		activation.$license.id = license
		activation.$computer.id = computer
		activation.verificationCount = 0

		return activation
	}

	init() {}
}
