//
//  Subscription.swift
//
//
//  Created by Emory Dunn on 10/16/23.
//

import Foundation
import Vapor
import Fluent

final class UpdateSubscription: Model, Content {

	static var schema: String = "subscription"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "date")
	var date: Date

	@OptionalField(key: "subscription_id")
	var subscriptionID: String?

	@Parent(key: "license_id")
	var license: LicenseModel

	init() {}

	init(id: UUID? = nil, date: Date = .now, subscriptionID: String?) {
		self.id = id
		self.date = date
		self.subscriptionID = subscriptionID
	}

	init(_ license: LicenseModel, subscriptionID: String? = nil) throws {
		self.date = license.date
		self.$license.id = try license.requireID()
		self.subscriptionID = subscriptionID
	}


}
