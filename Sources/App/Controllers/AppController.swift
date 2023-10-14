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
			app.post("create-intent", use: createIntent)
			app.get("create-intent", use: checkoutIntentInfo)
			app.get("complete", use: success)
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
	
	/// Render a checkout element which displays the app name & pricing and a payment form.
	/// - Parameter req: The request.
	/// - Returns: A checkout view.
	func checkout(req: Request) async throws -> View {
		guard 
			let app = try await App.find(req.parameters.get("appID"), on: req.db)
		else {
			throw Abort(.notFound)
		}

		let purchasePrice = try await req.stripe.prices.retrieve(price: app.purchaseID, expand: nil)
		let subPrice = try await req.stripe.prices.retrieve(price: app.subscriptionID!, expand: nil)

		let context = CheckoutContext(app.name,
									  bundleID: app.bundleID,
									  icon: "/images/\(app.name).png",
									  purchasePrice: purchasePrice,
									  subPrice: subPrice)

		return try await req.view.render("checkout", context)

	}

	func success(req: Request) async throws -> Response {

		guard
			let intent: String = req.query["payment_intent"]
		else {
			req.logger.log(level: .error, "Request has no payment intent")
			throw Abort(.badRequest)
		}

		req.logger.log(level: .info, "Decoded payment intent")

		let paymentIntent = try await req.stripe.paymentIntents.retrieve(intent: intent, clientSecret: nil)

		let showProcessingMessage: Bool

		switch paymentIntent.status {
		case .processing:
			// Probably all good?
			showProcessingMessage = true
		case .succeeded:
			// All good, continue
			showProcessingMessage = false
		default:
			req.logger.log(level: .warning, "Payment Intent needs attention, redirecting to checkout")
			var redirectURL = req.url

			if let clientSecret = paymentIntent.clientSecret {
				redirectURL.query = "payment_intent_client_secret=\(clientSecret)"
			}

			redirectURL.path = redirectURL.path.replacingOccurrences(of: "/complete", with: "/checkout")
			return req.redirect(to: redirectURL.string)
		}

		let app: App = try await App.find(req.parameters.get("appID"), on: req.db)

		guard
			let chargeID = paymentIntent.latestCharge,
			let charge = try? await req.stripe.charges.retrieve(charge: chargeID, expand: nil)
		else {
			req.logger.log(level: .error, "Failed to get latest charge for intent \(paymentIntent.id)")
			throw Abort(.notFound)
		}

		let context = CheckoutReceipt(name: app.name,
									  amount: paymentIntent.formattedAmount,
									  sub: paymentIntent.createSubscription,
									  showProcessingMessage: showProcessingMessage,
									  receiptUrl: charge.receiptUrl)

		return try await req.view.render("receipt", context).encodeResponse(for: req)
	}

	func checkoutIntentInfo(req: Request) async throws -> CheckoutIntent {
		guard
			let app = try await App.find(req.parameters.get("appID"), on: req.db)
		else {
			throw Abort(.notFound)
		}

		let purchasePrice = try await req.stripe.prices.retrieve(price: app.purchaseID, expand: nil)

		guard let check = CheckoutIntent(app: app, price: purchasePrice) else {
			throw Abort(.internalServerError)
		}

		return check
	}

	func createIntent(request: Request) async throws -> [String: String] {

		let app: App = try await App.find(request.parameters.get("appID"), on: request.db)

		let checkoutCustomer = try request.content.decode(CheckoutCustomer.self)

		let stripeCustomerID = try await request.returnUser(with: checkoutCustomer.email, name: checkoutCustomer.name)

		request.logger.log(level: .info, "Creating payment intent")

		// Store app metadata for future use
		let metadata = [
			"bundle_id": app.bundleID,
			"create_subscription": checkoutCustomer.subscribe.description
		]

		let purchasePrice = try await request.stripe.prices.retrieve(price: app.purchaseID, expand: nil)
		let intent = try await request.stripe.paymentIntents.create(amount: purchasePrice.unitAmount!,
																	currency: .usd,
																	automaticPaymentMethods: ["enabled": true],
																	confirm: nil,
																	customer: stripeCustomerID,
																	description: purchasePrice.nickname,
																	metadata: metadata,
																	offSession: nil,
																	paymentMethod: nil,
																	receiptEmail: nil,
																	setupFutureUsage: .offSession,
																	shipping: nil,
																	statementDescriptor: nil,
																	statementDescriptorSuffix: nil,
																	applicationFeeAmount: nil,
																	captureMethod: nil,
																	confirmationMethod: nil,
																	errorOnRequiresAction: nil,
																	mandate: nil,
																	mandateData: nil,
																	onBehalfOf: nil,
																	paymentMethodData: nil,
																	paymentMethodOptions: nil,
																	paymentMethodTypes: nil,
																	radarOptions: nil,
																	returnUrl: nil,
																	transferData: nil,
																	transferGroup: nil,
																	useStripeSDK: nil,
																	expand: nil)

		guard let secret = intent.clientSecret else {
			throw Abort(.badRequest)
		}

		request.logger.log(level: .info, "Returning intent \(intent.id) \(secret)")

		return ["clientSecret": secret]
	}

}
