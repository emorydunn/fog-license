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
			return try await activateLicense(for: paymentIntent, with: req)
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

	func activateLicense(for paymentIntent: PaymentIntent, with request: Request) async throws -> HTTPResponseStatus {

		// Look up the receipt for the PI
		let receipt = try await Receipt
			.findPayment(paymentIntent.id, on: request.db)

		// Look up the customer/user in our database
		guard let customer = paymentIntent.customer else { return .ok }
		let user = try await User.findCustomer(customer, on: request.db)

		// Update licenses
		try await request.db.transaction { db in

			request.logger.info("Starting db transaction with \(receipt.licenses.count) licenses")

			for license in receipt.licenses {
				request.logger.info("Activating license \(license.code)")
				// Mark as active now that the payment is complete
				license.isActive = true

				try await license.save(on: db)

				// Check if we need to create a subscription
				let app = try await license.$application.get(on: db)
				guard let subID = app.subscriptionID else {
					request.logger.info("Application \(app) does not use subscriptions")
					break
				}

				guard
					let sub = try await license.$subscription.get(on: db),
					let expiryDate = license.expiryDate
				else {
					request.logger.error("Failed to get requisite data to create subscription for license \(license)")
					break
				}

				// Create the subscription
				let newSub = try await request.createSubscription(subID,
																  for: customer,
																  subStartDate: expiryDate)
				request.logger.info("Created \(app.name) subscription for \(user.name)")

				sub.subscriptionID = newSub.id

				// Save everything
				try await sub.save(on: db)
			}

			request.logger.info("Finishing web hook db transaction")
		}

		return .ok

	}
}
