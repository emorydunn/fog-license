//
//  ReceiptController.swift
//
//
//  Created by Emory Dunn on 10/18/23.
//

import Foundation
import Vapor
import Fluent

struct ReceiptController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let group = routes.grouped("receipts")

		group.get(use: index)
		group.post(use: create)
		group.group(":receiptID") { receipt in
			receipt.get(use: fetch)
			receipt.delete(use: delete)
		}
	}

	func index(req: Request) async throws -> [Receipt] {
		try await Receipt.query(on: req.db).all()
	}

	func fetch(req: Request) async throws -> Receipt {
		guard let receipt = try await Receipt
			.find(req.parameters.get("receiptID"), on: req.db)
		else {
			throw Abort(.notFound)
		}

		try await receipt.$licenses.load(on: req.db)

		return receipt

	}

	func create(req: Request) async throws -> Receipt {
		// Decode the model in transit
		let body = try req.content.decode(Receipt.Create.self)

		req.logger.log(level: .info, "Creating new receipt for payment \(body.paymentID)")

		// Create the DB model
		let receipt = Receipt(date: body.date, paymentID: body.paymentID)

		// Save the model and licenses in a transaction
		try await req.db.transaction { db in
			req.logger.log(level: .debug, "Saving receipt \(receipt)")
			try await receipt.save(on: db)

			// Add the licenses to the receipt
//			try await receipt.addLicenses(body.licenses, on: db)
			for license in body.licenses {
				let app = try await license.$application.get(on: db)
				let purchasePrice = try await req.stripe.prices.retrieve(price: app.purchaseID, expand: nil)

				// Attach the license to the receipt, updating the line item info
				try await receipt.addLicense(license, on: db) { pivot in
					pivot.amount = purchasePrice.unitAmount!
					pivot.description = purchasePrice.nickname ?? app.name
					pivot.requestedUpdates = false
				}
			}
			try await receipt.$licenses.load(on: db)
		}

		// Return a model for transit
		return receipt
	}

	func delete(req: Request) async throws -> HTTPStatus {
		guard let receipt = try await Receipt
			.find(req.parameters.get("receiptID"), on: req.db)
		else {
			throw Abort(.notFound)
		}

		try await req.db.transaction { db in
			try await receipt.removeLicenses(on: db)
			try await receipt.delete(on: db)
		}

		return .noContent
	}
}
