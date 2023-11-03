import Fluent
import Vapor

final class User: Model, Content {
	static let schema = "users"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "name")
	var name: String

	@Field(key: "email")
	var email: String

	@OptionalField(key: "external_id")
	var externalID: String?

	@Children(for: \.$user)
	var licenses: [LicenseModel]

	init() { }

	init(id: UUID? = nil, name: String, email: String, externalID: String? = nil) {
		self.id = id
		self.name = name
		self.email = email
		self.externalID = externalID
	}

}

extension User {
	static func findCustomer(_ id: String?, on db: Database) async throws -> User {
		guard let user = try await User
			.query(on: db)
			.filter(\.$externalID == id)
			.first()
		else {
			throw Abort(.notFound)
		}

		return user
	}

	static func find(email: String, on db: Database) async throws -> User {
		guard let user = try await User
			.query(on: db)
			.filter(\.$email == email)
			.first()
		else {
			throw Abort(.notFound)
		}

		return user
	}
}
