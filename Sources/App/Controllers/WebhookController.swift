//
//  WebhookController.swift
//
//
//  Created by Emory Dunn on 10/13/23.
//

import Foundation
import Vapor
import StripeKit
import Fluent

struct WebhookController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.post("webhook", use: handleStripeWebhooks)
	}

	func handleStripeWebhooks(req: Request) async throws -> HTTPResponseStatus {

		#if DEBUG
		req.logger.log(level: .notice, "Skipping webhook signature verification")
		#else
		try StripeClient.verifySignature(for: req, secret: req.stripeWebhookSecret)
		#endif

		// Stripe dates come back from the Stripe API as epoch and the StripeModels convert these into swift `Date` types.
		// Use a date and key decoding strategy to successfully parse out the `created` property and snake case strpe properties.
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970
		decoder.keyDecodingStrategy = .convertFromSnakeCase

		let event = try req.content.decode(Event.self, using: decoder)

		switch (event.type, event.data?.object) {
		case (.paymentIntentSucceeded, .paymentIntent(let paymentIntent)):
			req.logger.log(level: .info, "Processing Payment Intent Succeeded Webhook")
			return try await generateLicense(for: paymentIntent, with: req)
//		case (.customerSubscriptionCreated, .subscription(let subscription)):
//			return .ok
//		case (.customerSubscriptionDeleted, .subscription(let subscription)):
//			return .ok
//		case (.customerSubscriptionResumed, .subscription(let subscription)):
//			return .ok
		default:
			return .ok
		}
	}

	func generateLicense(for paymentIntent: PaymentIntent, with request: Request) async throws -> HTTPResponseStatus {

		// Look up the receipt for the PI
		let receipt = try await Receipt
			.findPayment(paymentIntent.id, on: request.db)

		// Look up the customer/user in our database
		guard let customer = paymentIntent.customer else { return .ok}
		let user = try await User.findCustomer(customer, on: request.db)

		// Update licenses
		try await request.db.transaction { db in

			request.logger.log(level: .info, "Starting db transaction with \(receipt.licenses.count) licenses ")

			for license in receipt.licenses {
				request.logger.log(level: .info, "Activating license \(license.code)")
				// Mark as active now that the payment is complete
				license.isActive = true

				try await license.save(on: db)

				// Check if we need to create a subscription
				let app = try await license.$application.get(on: db)
				guard let subID = app.subscriptionID else {
					request.logger.log(level: .info, "Application \(app) does not use subscriptions")
					break
				}

				guard
					let sub = try await license.$subscription.get(on: db),
					let expiryDate = license.expiryDate
				else {
					request.logger.log(level: .error, "Failed to get requisite data to create subscription for license \(license)")
					break
				}

				// Create the subscription
				let newSub = try await request.createSubscription(subID,
																  for: customer,
																  subStartDate: expiryDate)
				request.logger.log(level: .info, "Created \(app.name) subscription for \(user.name)")

				sub.subscriptionID = newSub.id

				// Save everything
				try await sub.save(on: db)
			}

			request.logger.log(level: .info, "Finishing webhook db transaction")
		}

//		guard paymentIntent.status == .succeeded else {
//			request.logger.log(level: .error, "The payment did not succeed (\(paymentIntent.status?.rawValue ?? "unknown")), skipping license generation")
//			return .ok
//		}
//
//		guard let app = try await App.find(paymentIntent.metadata?["bundle_id"], on: request.db) else {
//			request.logger.log(level: .error, "Webhook does not contain a bundle_id")
//			return .ok
//		}
//
//		// Look up the customer/user in our database
//		guard
//			let customer = paymentIntent.customer,
//			let user = try await User.query(on: request.db).filter(\.$externalID == customer).first()
//		else {
//			request.logger.log(level: .error, "Payment intent had no customer")
//			return .ok
//		}
//
//		let expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date.now)
//		let newLicense = try LicenseModel(app: app,
//										  user: user,
////										  payment: paymentIntent,
//										  expiryDate: expiryDate)
//
//		try await newLicense.save(on: request.db)
//
//		request.logger.log(level: .info, "Created \(app.name) license for \(user.name) which expires on \(expiryDate?.formatted() ?? "never")")
//
//		if paymentIntent.createSubscription, let subscriptionID = app.subscriptionID {
//			let sub = try await request.createSubscription(subscriptionID, for: customer)
//			request.logger.log(level: .info, "Created \(app.name) subscription for \(user.name)")
//
////			newLicense.subscriptionID = sub.id
//			try await newLicense.update(on: request.db)
//		}

		return .ok

	}
}
