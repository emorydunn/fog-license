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
			.field("bundle_identifier", .string, .required)
			.field("name", .string, .required)
			.field("default_activation_count", .int8, .sql(.notNull), .sql(.default(3)))
			.field("purchase_id", .string, .required)
			.field("subscription_id", .string)
			.unique(on: "number", "bundle_identifier", "name")
			.create()

		try await database.schema(LicenseModel.schema)
			.id()
			.field("activation_date", .date, .required)
			.field("update_date", .date)
			.field("creation_date", .date)
			.field("expiry_date", .date)
			.field("code", .int, .required)
			.field("allowed_activation_count", .int, .required)
			.field("is_active", .bool, .required)
			.field("application_id", .uuid, .required, .references(App.schema, "id"))
			.field("user_id", .uuid, .required, .references(User.schema, "id"))
			.unique(on: "code")
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

		try await database.schema(ComputerInfo.schema)
			.id()
			.field("hardware_id", .string, .required)
			.field("friendly_name", .string)
			.field("model", .string, .required)
			.field("os_version", .string, .required)
			.unique(on: "hardware_id")
			.create()

		try await database.schema(Activation.schema)
			.id()
			.field("first_activation", .date, .required)
			.field("last_verified", .date)
			.field("deactivated_date", .date)
			.field("license_id", .uuid, .required, .references(LicenseModel.schema, "id"))
			.field("computer_id", .uuid, .required, .references(ComputerInfo.schema, "id"))
			.field("verification_count", .int, .required, .sql(.default(0)))
			.create()

	}

	func revert(on database: Database) async throws {
	}
}
