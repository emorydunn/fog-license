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

//	@Field(key: "first_activation")
	@Timestamp(key: "first_activation", on: .create)
	var firstActivation: Date?

	@Timestamp(key: "deactivated_date", on: .delete)
	var deactivatedDate: Date?

//	@Field(key: "last_verified")
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


	static func find(license: LicenseModel.IDValue, computer: ComputerInfo.IDValue, on db: Database) async throws -> Activation {
		if let activation = try await Activation.query(on: db)
			.group(.and, { group in
				group.filter(Activation.self, \.$license.$id == license)
				group.filter(Activation.self, \.$computer.$id == computer)
			}).first() {
			return activation
		}

		let activation = Activation()

		activation.$license.id = license
		activation.$computer.id = computer
		activation.verificationCount = 0

		return activation
	}

//	@Field(key: "is_active")
//	var isActive: Bool

	init() {}
}
