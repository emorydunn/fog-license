//
//  File.swift
//  
//
//  Created by Emory Dunn on 10/16/23.
//

import Foundation
import Fluent
@testable import App
import SharedModels

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
	static var test: App.Stub { 
		App.Stub(name: "Test App",
				 bundleIdentifier: "com.test.app",
				 activationCount: 3,
				 purchaseID: "price_1O0CEp2dG3awZnDi2Tn0k345",
				 subscriptionID: "price_1O0BP62dG3awZnDiuDKZXi4J")
	}
	
	static func saveTest(on db: Database) async throws -> App {
		let newApp = try await App(App.test, on: db)
		try await newApp.save(on: db)
		return newApp
	}
}

extension AppInfo {
	static let test = AppInfo(name: "Test App",
							  bundleIdentifier: "com.test.app",
							  purchase: PurchaseInfo(id: "price_1O0CEp2dG3awZnDi2Tn0k345", amount: 50),
							  number: 1,
							  activationCount: 3,
							  licenseCount: 0,
							  subscriberCount: 0)
}

extension User: TestModel {
	static var test: User { User(name: "Test User", email: "test@test.com") }
}

extension ComputerInfo: TestModel {
	static var test: ComputerInfo {
		ComputerInfo(id: nil, //UUID(uuidString: "4AF8C1E3-CCB7-4B3D-9DAF-5FDD2BCFAF71"),
					 hardwareIdentifier: "fakecomputer",
					 friendlyName: "Fake Computer",
					 model: "Test1,1",
					 osVersion: "14.0.0")
	}
}

extension App {
	func bootstrapDatabase() async throws {
		
	}
}
