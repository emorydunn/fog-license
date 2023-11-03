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
import SharedModels

struct AppController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let apps = routes.grouped("apps")

		apps.get(use: index)
		apps.post(use: create)
		apps.group(":appID") { app in
			app.get(use: fetch)
			app.put(use: update)
			app.delete(use: delete)
		}

	}

	func index(req: Request) async throws -> [AppInfo] {
		return try await withThrowingTaskGroup(of: AppInfo.self, returning: [AppInfo].self) { group in
			for app in try await App.query(on: req.db).all() {
				group.addTask {
					try await AppInfo(app.bundleIdentifier, db: req.db, stripe: req.stripe)
				}
			}

			var infos = [AppInfo]()
			for try await app in group {
				infos.append(app)
			}

			return infos
		}
	}

	func fetch(req: Request) async throws -> AppInfo {
		return try await AppInfo(req.parameters.get("appID"), db: req.db, stripe: req.stripe)
	}

	func update(req: Request) async throws -> AppInfo {
		let app: App = try await App.find(req.parameters.get("appID"), on: req.db)
		let stub = try req.content.decode(AppInfo.self)

		app.name = stub.name
		app.bundleIdentifier = stub.bundleIdentifier
		app.activationCount = stub.activationCount
		app.purchaseID = stub.purchase.id
		app.subscriptionID = stub.subscription?.id

		try await app.save(on: req.db)

		return try await AppInfo(app, db: req.db, stripe: req.stripe)
	}

	func create(req: Request) async throws -> AppInfo {
		let stub = try req.content.decode(AppInfo.self)

		let app = try await App(stub, on: req.db)

		try await app.save(on: req.db)
		return try await AppInfo(app, db: req.db, stripe: req.stripe)
	}

	func delete(req: Request) async throws -> HTTPStatus {
		let app: App = try await App.find(req.parameters.get("appID"), on: req.db)
		try await app.delete(on: req.db)
		return .noContent
	}

}
