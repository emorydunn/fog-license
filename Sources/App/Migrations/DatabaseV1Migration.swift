import Fluent

struct DatabaseV1Migration: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(User.schema)
			.id()
			.field("name", .string, .required)
			.field("email", .string, .required, .sql(.unique))
			.field("external_id", .string, .sql(.unique))
			.create()

		try await database.schema(App.schema)
			.id()
			.field("number", .int8, .required, .sql(.unique))
			.field("bundle_id", .string, .required, .sql(.unique))
			.field("name", .string, .required, .sql(.unique))
			.field("default_activation_count", .int8, .sql(.notNull), .sql(.default(3)))
			.field("purchase_id", .string, .required)
			.field("subscription_id", .string)
			.create()

		try await database.schema(LicenseModel.schema)
			.id()
			.field("code", .int, .required, .sql(.unique))
			.field("allowed_activation_count", .int, .required)
			.field("application_id", .uuid, .required, .references(App.schema, "id"))
			.field("user_id", .uuid, .required, .references(User.schema, "id"))
			.field("payment_id", .int, .required, .sql(.unique))
			.field("subscription_id", .int, .required, .sql(.unique))
			.create()

		print("Adding test data")
		// Create some default data
		try await App(name: "ScreeningRoom",
					  bundleID: "photo.lostcause.ScreeningRoom",
					  purchaseID: "price_1O0CEp2dG3awZnDi2Tn0k345",
					  subscriptionID: "price_1O0BP62dG3awZnDiuDKZXi4J",
					  on: database).save(on: database)

		try await App(name: "MonitorControl",
					  bundleID: "photo.lostcause.MonitorControl",
					  purchaseID: "price_1O0nEN2dG3awZnDin23HBkkO",
					  subscriptionID: "price_1O0nEN2dG3awZnDiz9PsWekC",
					  on: database).save(on: database)

		try await User(name: "Emory Dunn", email: "emory@emorydunn.com", externalID: "cus_OoA7qjmZMn7tfc").save(on: database)

	}

	func revert(on database: Database) async throws {
		try await database.schema(User.schema).delete()
		try await database.schema(App.schema).delete()
		try await database.schema(LicenseModel.schema).delete()
	}
}
