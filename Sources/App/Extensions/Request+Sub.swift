//
//  Request+Sub.swift
//  
//
//  Created by Emory Dunn on 10/16/23.
//

import Foundation
import Vapor
import StripeKit


extension Request {

	func createSubscription(_ subID: String, for customer: String, subStartDate: Date) async throws -> Subscription {
		logger.log(level: .info, "Creating subscription")
//		let subStartDate = Calendar.current.date(byAdding: .year, value: 1, to: Date.now)

		let items: [[String: Any]] = [
			["price" : subID]
		]

		let cards = try await stripe.paymentMethods.listAll(customer: customer, type: .card, filter: nil)

		//		stripe.customers.retrieve(customer: customer, expand: nil).defaultSource

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

