//
//  Request+User.swift
//
//
//  Created by Emory Dunn on 10/16/23.
//

import Foundation
import Vapor
import Fluent
import StripeKit


extension Request {

	/// Search for a customer with the specified email address, creating one if needed.
	/// - Parameters:
	///   - email: The email address to look up.
	///   - name: The name to use when creating a new customer, if needed.
	/// - Returns: A `Customer`.
	func getOrCreateCustomer(with email: String, name: String?) async throws -> Customer {
		let query = "email:'\(email)'"
		let searchResult = try await stripe.customers.search(query: query, limit: 1, page: nil, expand: nil)
		
		guard let customer = searchResult.data?.first else {
			logger.log(level: .debug, "Creating new Stripe customer!")
			return try await stripe.customers.create(address: nil,
													 description: nil,
													 email: email,
													 metadata: nil,
													 name: name,
													 paymentMethod: nil,
													 phone: nil,
													 shipping: nil,
													 balance: nil,
													 cashBalance: nil,
													 coupon: nil,
													 invoicePrefix: nil,
													 invoiceSettings: nil,
													 nextInvoiceSequence: nil,
													 preferredLocales: nil,
													 promotionCode: nil,
													 source: nil,
													 tax: nil,
													 taxExempt: nil,
													 taxIdData: nil,
													 testClock: nil,
													 expand: nil)
		}
		
		logger.log(level: .debug, "Returning existing Stripe customer")
		return customer
		
	}
	
	/// Return a `User` for the given email address.
	///
	/// ```
	///             ┌────────────────────┐
	///             │    Search Users    │
	///             └────────────────────┘
	///                        │
	///                        │
	///           ┌────────────┴─User Found─────┐
	///           │   Not Found                 │
	///           ▼                             ▼
	/// ┌──────────────────┐           ┌─────────────────┐
	/// │ Search Customers │───┐       │Check External ID│────┐
	/// └──────────────────┘   │       └─────────────────┘    │
	///           │            │                │             │
	///           │            │             No ID            │
	///           │        Customer             │             │
	///           │       Not Found             │             │
	///           │            │                ▼             │
	///           │            │       ┌────────────────┐     │
	///           │            │       │   Create New   │     │
	///           │            │       │    Customer    │  Has ID
	///           │            └──┐    └────────────────┘     │
	///           │               │             │             │
	///           │               ▼             │             │
	///           │      ┌────────────────┐     │             │
	///           │      │Create New User │     │             │
	///           │      └────────────────┘     │             │
	///           │               │             │             │
	///           │               │             │             │
	///           │               │             │             │
	///           │               │             ▼             │
	///       Customer            │  ╔═════════════════════╗  │
	///        Found──────────────┴─▶║     Return User     ║◀─┘
	///                              ╚═════════════════════╝
	/// ```
	///
	/// - Parameters:
	///   - email: The email address to search for.
	///   - name: The name to use if a `User` needs to be created. The name is _not_ used as part of the query.
	/// - Returns: The Stripe Customer ID.
	func getOrCreateUser(with email: String, name: String) async throws -> User {
		logger.info("Searching for user with email address '\(email)'")
		let user = try await User.query(on: db)
						.filter(\.$email == email)
						.first() ?? User(name: name, email: email)

		try await createCustomer(for: user)

		return user
		
	}
	
	/// Create a Stripe Customer for the user, if needed.
	/// - Parameter user: The User to update.
	func createCustomer(for user: User) async throws {

		guard user.externalID == nil else {
			logger.log(level: .info, "\(user) is already linked to Stripe")
			return
		}

		logger.log(level: .info, "Creating customer for \(user)")
		let customer = try await stripe.customers.create(address: nil,
														 description: nil,
														 email: user.email,
														 metadata: nil,
														 name: user.name,
														 paymentMethod: nil,
														 phone: nil,
														 shipping: nil,
														 balance: nil,
														 cashBalance: nil,
														 coupon: nil,
														 invoicePrefix: nil,
														 invoiceSettings: nil,
														 nextInvoiceSequence: nil,
														 preferredLocales: nil,
														 promotionCode: nil,
														 source: nil,
														 tax: nil,
														 taxExempt: nil,
														 taxIdData: nil,
														 testClock: nil,
														 expand: nil)

		logger.log(level: .info, "Updating user with external ID")
		user.externalID = customer.id
		try await user.save(on: db)
	}
}
