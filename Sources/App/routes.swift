import Fluent
import Vapor
import StripeKit

func routes(_ app: Application) throws {

	try app.register(collection: AppController())
	try app.register(collection: UserController())
	try app.register(collection: WebhookController())
	try app.register(collection: CheckoutController())



//	app.get("success") { request async throws -> String in
//		guard
//			let intent: String = request.query["payment_intent"],
//			let redirectStatus: String = request.query["redirect_status"]
//		else {
//			return "Unable to decode intent"
//		}
//
//		//			let decodedIntent = try request.query.decode(PaymentIntent.self)
//		request.logger.log(level: .info, "Decoded payment intent")
//		//		print(intent, clientSecret, redirectStatus)
//
//		let paymentIntent = try await request.stripe.paymentIntents.retrieve(intent: intent, clientSecret: nil)
//
//		guard let customer = paymentIntent.customer else {
//			request.logger.log(level: .info, "Payment intent had no customer")
//			return redirectStatus
//		}
//
//		// TODO: Create a license for the purchase
//
////		try LicenseModel(application: <#T##App#>, user: <#T##User#>)
//
//		if paymentIntent.createSubscription {
//			try await app.createSubscription(for: customer, with: request)
//		}
//
//		return redirectStatus
//
//	}

//	app.get("checkout", ":bundleID") { request -> View in
//	}


//	app.get("checkout") { request -> View in
//
////		let product = try await request.stripe.products.retrieve(id: "prod_Onmz4tGfmzciVG")
//		let purchasePrice = try await request.stripe.prices.retrieve(price: "price_1O0CEp2dG3awZnDi2Tn0k345", expand: nil)
//		let subPrice = try await request.stripe.prices.retrieve(price: "price_1O0BP62dG3awZnDiuDKZXi4J", expand: nil)
//
//		// TODO: Dynamic pricing
//		let context = CheckoutContext("ScreeningRoom",
//									  bundleID: "photo.lostcause.ScreeningRoom",
//									  icon: "/images/ScreeningRoom.png",
//									  purchasePrice: purchasePrice,
//									  subPrice: subPrice)
//
//		return try await request.view.render("checkout", context)
//	}

	app.post("create-intent") { request -> [String: String] in

		let checkoutCustomer = try request.content.decode(CheckoutCustomer.self)

		let stripeCustomerID = try await request.returnUser(with: checkoutCustomer.email, name: checkoutCustomer.name)

		request.logger.log(level: .info, "Creating payment intent")

		// TODO: Dynamic pricing
		let purchasePrice = try await request.stripe.prices.retrieve(price: "price_1O0CEp2dG3awZnDi2Tn0k345", expand: nil)
		let intent = try await request.stripe.paymentIntents.create(amount: purchasePrice.unitAmount!,
																	currency: .usd,
																	automaticPaymentMethods: ["enabled": true],
																	confirm: nil,
																	customer: stripeCustomerID,
																	description: purchasePrice.nickname,
																	metadata: ["create_subscription": checkoutCustomer.subscribe.description],
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

extension Request {

//	func searchOrCreateCustomer(for checkoutCustomer: CheckoutCustomer) async throws -> Customer {
	func searchOrCreateCustomer(with email: String, name: String?) async throws -> Customer {
		let query = "email:'\(email)'"
		let searchResult = try await stripe.customers.search(query: query, limit: 1, page: nil, expand: nil)

		guard let customer = searchResult.data?.first else {
			logger.log(level: .info, "Creating new customer!")
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

		logger.log(level: .info, "Using existing customer for purchase!")
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
	///        Found──────────────┴─▶║ Return Customer ID  ║◀─┘
	///                              ╚═════════════════════╝
	/// ```
	///
	/// - Parameters:
	///   - email: The email address to search for.
	///   - name: The name to use if a `User` needs to be created. The name is _not_ used as part of the query.
	/// - Returns: The Stripe Customer ID.
	func returnUser(with email: String, name: String) async throws -> String {

		guard 
			let user = try await User.query(on: db)
			.filter(\.$email == email)
			.first() 
		else {
			logger.log(level: .info, "No existing User with email \(email)")

			logger.log(level: .info, "Creating new Stripe customer")
			let customer = try await searchOrCreateCustomer(with: email, name: name)

			let newUser = User(name: name, email: email, externalID: customer.id)

			logger.log(level: .info, "Saving new user")
			try await newUser.save(on: db)

			return customer.id
		}

		if let externalID = user.externalID {
			logger.log(level: .info, "User is linked to a Stripe customer, returning the ID")
			return externalID
		}

		logger.log(level: .info, "Creating new Stripe customer")
		let newCustomer = try await stripe.customers.create(address: nil,
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
		user.externalID = newCustomer.id
		try await user.save(on: db)

		return newCustomer.id

	}

	func createSubscription(_ subID: String, for customer: String) async throws -> Subscription {
		logger.log(level: .info, "Creating subscription")
		let subStartDate = Calendar.current.date(byAdding: .year, value: 1, to: Date.now)

		let items: [[String: Any]] = [
			["price" : subID]
		]

		let cards = try await stripe.paymentMethods.listAll(customer: customer, type: .card, filter: nil)

		let defaultSource = cards.data?.first

		let sub = try await stripe.subscriptions.create(customer: customer,
																items: items,
																cancelAtPeriodEnd: false,
																currency: .usd,
																defaultPaymentMethod: defaultSource?.id,
																description: nil,
																metadata: nil,
																paymentBehavior: nil,
																addInvoiceItems: nil,
																applicationFeePercent: nil,
																automaticTax: nil,
																backdateStartDate: nil,
																billingCycleAnchor: subStartDate,
																billingThresholds: nil,
																cancelAt: nil,
																collectionMethod: nil,
																coupon: nil,
																daysUntilDue: nil,
																defaultSource: nil,
																defaultTaxRates: nil,
																offSession: nil,
																onBehalfOf: nil,
																paymentSettings: nil,
																pendingInvoiceItemInterval: nil,
																promotionCode: nil,
																prorationBehavior: SubscriptionProrationBehavior.none,
																transferData: nil,
																trialEnd: nil,
																trialFromPlan: nil,
																trialPeriodDays: nil,
																trialSettings: nil,
																expand: nil)

		logger.log(level: .info, "Created subscription starting on \(sub.billingCycleAnchor!)")

		return sub

	}
}
