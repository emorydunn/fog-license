import Fluent

struct DatabaseV1Migration: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(User.schema)
			.id()
			.field("name", .string, .required)
			.field("email", .string, .required)
			.field("external_id", .string)
			.unique(on: "email", "external_id")
			.create()

		try await database.schema(App.schema)
			.id()
			.field("number", .int8, .required)
			.field("bundle_id", .string, .required)
			.field("name", .string, .required)
			.field("default_activation_count", .int8, .sql(.notNull), .sql(.default(3)))
			.field("purchase_id", .string, .required)
			.field("subscription_id", .string)
			.unique(on: "number", "bundle_id", "name")
			.create()

		try await database.schema(LicenseModel.schema)
			.id()
			.field("date", .date, .required)
			.field("expiry_date", .date)
			.field("code", .int, .required)
			.field("allowed_activation_count", .int, .required)
			.field("is_active", .bool, .required)
			.field("application_id", .uuid, .required, .references(App.schema, "id"))
			.field("user_id", .uuid, .required, .references(User.schema, "id"))
//			.field("receipt_item_id", .uuid, .references(ReceiptItem.schema, "id"))
//			.field("payment_id", .int)
//			.field("subscription_id", .int)
			.unique(on: "code")
//					"payment_id",
//					"subscription_id"
//			)
			.create()

		try await database.schema(Receipt.schema)
			.id()
			.field("date", .date, .required)
			.field("payment_id", .string, .required)
			.unique(on: "payment_id")
			.create()

		try await database.schema(ReceiptItem.schema)
			.id()
			.field("receipt_id", .uuid, .required, .references(Receipt.schema, "id"))
			.field("license_id", .uuid, .required, .references(LicenseModel.schema, "id"))
			.field("amount", .int, .required)
			.field("description", .string, .required)
			.field("requested_updates", .bool, .required)
			.unique(on: "receipt_id", "license_id")
			.create()

		try await database.schema(UpdateSubscription.schema)
			.id()
			.field("date", .date, .required)
			.field("subscription_id", .string)
			.field("license_id", .uuid, .required, .references(LicenseModel.schema, "id"))
			.create()



//		print("Adding test data")
//		// Create some default data
//		try await App(name: "ScreeningRoom",
//					  bundleID: "photo.lostcause.ScreeningRoom",
//					  purchaseID: "price_1O0CEp2dG3awZnDi2Tn0k345",
//					  subscriptionID: "price_1O0BP62dG3awZnDiuDKZXi4J",
//					  on: database).save(on: database)
//
//		try await App(name: "MonitorControl",
//					  bundleID: "photo.lostcause.MonitorControl",
//					  purchaseID: "price_1O0nEN2dG3awZnDin23HBkkO",
//					  subscriptionID: "price_1O0nEN2dG3awZnDiz9PsWekC",
//					  on: database).save(on: database)
//
//		try await User(name: "Emory Dunn", email: "emory@emorydunn.com", externalID: "cus_OoA7qjmZMn7tfc").save(on: database)

	}

	func revert(on database: Database) async throws {
		try await database.schema(User.schema).delete()
		try await database.schema(App.schema).delete()
		try await database.schema(LicenseModel.schema).delete()
	}
}
