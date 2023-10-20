import Fluent
import Vapor
import StripeKit

struct UserController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let customers = routes.grouped("users")
		
		customers.get(use: index)
		customers.post(use: create)
		customers.group(":userID") { todo in
			todo.get(use: getUser)
			todo.delete(use: delete)
		}
	}

	func index(req: Request) async throws -> [User] {
		try await User.query(on: req.db).all()
	}

	func create(req: Request) async throws -> User {
		let customer = try req.content.decode(User.self)
		try await customer.save(on: req.db)
		return customer
	}

	func delete(req: Request) async throws -> HTTPStatus {
		guard let customer = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound)
		}
		try await customer.delete(on: req.db)
		return .noContent
	}

	func getUser(req: Request) async throws -> User {

		if let user = try await User.find(req.parameters.get("userID"), on: req.db) {
			req.logger.log(level: .info, "Found user using ID")
			return user
		}

		guard 
			let userID = req.parameters.get("userID"),
			userID.hasPrefix("cus")
		else {
			req.logger.log(level: .info, "ID isn't a Stripe customer")
			throw Abort(.notFound)
		}
		
		guard let user = try await User.query(on: req.db)
			.filter(\.$externalID == userID)
			.first() else {

			req.logger.log(level: .info, "Could not find user with external ID")
			throw Abort(.notFound)
		}

		req.logger.log(level: .info, "Found user using external ID")
		return user
	}

}
