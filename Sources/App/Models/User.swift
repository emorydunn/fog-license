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

	@Field(key: "external_id")
	var externalID: String?

	init() { }

	init(id: UUID? = nil, name: String, email: String, externalID: String? = nil) {
		self.id = id
		self.name = name
		self.email = email
		self.externalID = externalID
	}


}
