//
//  CheckoutController.swift
//
//
//  Created by Emory Dunn on 10/15/23.
//

import Foundation
import Vapor
import Fluent
import StripeKit

struct CheckoutController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let checkoutGroup = routes.grouped("checkout")

		checkoutGroup.group(":appID") { app in
			app.get(use: checkout)
			app.post(use: checkoutIntentInfo)
			app.on(.CHECKOUT, use: checkoutIntentInfo)

			app.post("create-intent", use: createIntent)

		}

		checkoutGroup.get("complete", use: success)

	}

	/// Render a checkout element which displays the app name & pricing and a payment form.
	/// - Parameter req: The request.
	/// - Returns: A checkout view.
	func checkout(req: Request) async throws -> View {
		let app: App = try await App.find(req.parameters.get("appID"), on: req.db)

		let purchasePrice = try await req.stripe.prices.retrieve(price: app.purchaseID, expand: nil)
		let subPrice = try await req.stripe.prices.retrieve(price: app.subscriptionID!, expand: nil)

		let context = CheckoutContext(app.name,
									  bundleID: app.bundleIdentifier,
									  icon: "/images/\(app.bundleIdentifier).png",
									  purchasePrice: purchasePrice,
									  subPrice: subPrice)

		if let host = req.url.host {
			req.headers.add(name: "Content-Security-Policy", value: "frame-src \(host)")
		}

		req.headers.add(name: "Content-Security-Policy", value: "script-src https://js.stripe.com")

		return try await req.view.render("checkout", context)

	}
	
	/// The return page after checkout.
	///
	/// This method verifies the Payment Intent succeeded and shows a receipt page. 
	///
	/// If the intent didn't succeed the request is redirected to the checkout page with the
	/// client secret and an error message so the user can attempt payment again.
	func success(req: Request) async throws -> Response {

		guard
			let intent: String = req.query["payment_intent"]
		else {
			throw Abort(.badRequest, reason: "Request is missing a payment intent")
		}


		let paymentIntent = try await req.stripe.paymentIntents.retrieve(intent: intent, clientSecret: nil)
		req.logger.log(level: .debug, "Decoded payment intent")

		if let host = req.url.host {
			req.headers.add(name: "Content-Security-Policy", value: "frame-src \(host)")
		}

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
				redirectURL.query = "payment_intent_client_secret=\(clientSecret)&status_message=\(paymentIntent.statusMessage)"
					.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
			}

			redirectURL.path = redirectURL.path.replacingOccurrences(of: "/complete", with: "")
			return req.redirect(to: redirectURL.string)
		}

		guard
			let chargeID = paymentIntent.latestCharge,
			let charge = try? await req.stripe.charges.retrieve(charge: chargeID, expand: nil)
		else {
			req.logger.log(level: .error, "Failed to get latest charge for intent \(paymentIntent.id)")
			throw Abort(.notFound, reason: "Payment intent has not been charged")
		}


		let receipt = try await Receipt.findPayment(intent, on: req.db)
		var paymentMethod: PaymentMethod?
		if let id = paymentIntent.paymentMethod {
			paymentMethod = try await req.stripe.paymentMethods.retrieve(paymentMethod: id, expand: ["card"])
		}

		let items = try await receipt.$items
			.get(on: req.db)
			.map { item in
				FullReceipt.Item(name: item.description,
								 price: item.amount.formatted(.currency(code: paymentIntent.currency?.rawValue ?? "usd")),
								 includesUpdates: item.requestedUpdates,
								 updateStartDate: nil)
		}
		let context = FullReceipt(date: receipt.date,
								  totalAmount: paymentIntent.formattedAmount,
								  showProcessingMessage: showProcessingMessage, 
								  payment: FullReceipt.Payment(paymentMethod),
								  receiptURL: charge.receiptUrl, items: items)

		return try await req.view.render("receipt", context).encodeResponse(for: req)
	}

	/// Return the information necessary to initialize Stripe's Payment Elements.
	/// - Parameter req: The HTTP request.
	/// - Returns: A `CheckoutIntent` used to set up a payment.
	func checkoutIntentInfo(req: Request) async throws -> CheckoutIntent {
		let app: App = try await App.find(req.parameters.get("appID"), on: req.db)

		let purchasePrice = try await req.stripe.prices.retrieve(price: app.purchaseID, expand: nil)

		guard let check = CheckoutIntent(app: app, price: purchasePrice) else {
			throw Abort(.internalServerError, reason: "Could not create CheckoutIntent for \(purchasePrice.nickname ?? purchasePrice.id)")
		}

		return check
	}
	
	/// Create a Payment Intent with Stripe and return the `clientSecret`
	func createIntent(request: Request) async throws -> [String: String] {

		request.logger.info("Creating payment intent")

		// Parse the app from the URL
		let app: App = try await App.find(request.parameters.get("appID"), on: request.db)

		// Decode the info sent from the client
		let checkoutCustomer = try request.content.decode(CheckoutCustomer.self)

		let user = try await request.getOrCreateUser(with: checkoutCustomer.email, name: checkoutCustomer.name)

		request.logger.info("Creating payment intent for \(user.name) to buy \(app.name)")

		// Fetch the price info and create a payment intent with Stripe
		let purchasePrice = try await request.stripe.prices.retrieve(price: app.purchaseID, expand: nil)
		let intent = try await request.stripe.createPaymentIntent(by: user, for: purchasePrice)

		guard let secret = intent.clientSecret else {
			throw Abort(.badRequest, reason: "Failed to create payment intent")
		}

		// Create a new receipt for the transaction
		let receipt = Receipt(paymentID: intent.id)

		// Generate the license code
		// The new license will be activated once the payment succeeds
		let newLicense = try LicenseModel(app: app,
										  user: user,
										  isActive: false,
										  expiryDate: app.expirationDate())

		request.logger.info("Created receipt and license for transaction")

		// Ensure the whole checkout succeeds
		try await request.db.transaction { db in
			// Save the receipt
			try await receipt.save(on: db)

			// Attach the license to the receipt, updating the line item info
			try await receipt.addLicense(newLicense, on: db) { pivot in
				pivot.amount = purchasePrice.unitAmount!
				pivot.description = purchasePrice.nickname ?? app.name
				pivot.requestedUpdates = checkoutCustomer.subscribe
			}

			// If the user requested a subscription, go ahead and set that up
			// The Stripe subscription will be created once the payment succeeds
			if checkoutCustomer.subscribe {
				let newSub = try UpdateSubscription(newLicense)
				try await newLicense.$subscription.create(newSub, on: db)
			}
		}

		request.logger.log(level: .info, "Returning intent \(intent.id) \(secret)")

		return ["clientSecret": secret]
	}
}
