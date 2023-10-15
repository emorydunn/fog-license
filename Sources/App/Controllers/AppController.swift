//
//  File.swift
//  
//
//  Created by Emory Dunn on 10/12/23.
//

import Foundation
import Vapor
import Fluent
import StripeKit

struct AppController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let apps = routes.grouped("app")

		apps.get(use: index)
		apps.post(use: create)
		apps.group(":appID") { app in
			app.get(use: fetch)
			app.delete(use: delete)
			app.get("checkout", use: checkout)
			app.get(use: checkout)
//			app.on(.OPTIONS, "checkout", use: checkoutIntentInfo)
//			app.post("create-intent", use: createIntent)
////			app.get("create-intent", use: checkoutIntentInfo)
//			app.get("complete", use: success)
		}

	}

	func index(req: Request) async throws -> [App] {
		try await App.query(on: req.db).all()
	}

	func fetch(req: Request) async throws -> App {
		return try await App.find(req.parameters.get("appID"), on: req.db)
	}

	func create(req: Request) async throws -> App {
		let app = try req.content.decode(App.self)
		try await app.save(on: req.db)
		return app
	}

	func delete(req: Request) async throws -> HTTPStatus {
		let app: App = try await App.find(req.parameters.get("appID"), on: req.db)
		try await app.delete(on: req.db)
		return .noContent
	}

	func checkout(req: Request) async throws -> HTTPStatus {
		return .ok
	}


}
