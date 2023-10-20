//
//  File.swift
//  
//
//  Created by Emory Dunn on 10/16/23.
//

import Foundation
import Fluent
@testable import App

protocol TestModel {
	associatedtype TM
	static var test: TM { get }

	@discardableResult
	static func saveTest(on db: Database) async throws -> Self
}

extension TestModel where TM: Model {
	@discardableResult
	static func saveTest(on db: Database) async throws -> TM {
		let newModel = Self.test
		try await newModel.create(on: db)
		return newModel
	}
}

extension App: TestModel {
	static var test: App.Stub { App.Stub(name: "Test App",
									bundleID: "com.test.app",
									activationCount: 3,
									purchaseID: "price_123",
									subscriptionID: "price_546")
	}

	static func saveTest(on db: Database) async throws -> App {
		let newApp = try await App(App.test, on: db)
		try await newApp.save(on: db)
		return newApp
	}
}

extension User: TestModel {
	static var test: User { User(name: "Test User", email: "test@test.com") }
}
