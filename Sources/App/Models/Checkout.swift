//
//  Checkout.swift
//  
//
//  Created by Emory Dunn on 10/12/23.
//

import Foundation
import StripeKit
import Vapor

struct CheckoutContext: Encodable {
	let appName: String
	let bundleID: String
	let purchasePrice: String
	let updatePrice: String
	let icon: String
	let startDate: String

	init(_ name: String, bundleID: String, icon: String, purchasePrice: Price, subPrice: Price) {
		self.appName = name
		self.bundleID = bundleID
		self.icon = icon

		self.purchasePrice = purchasePrice.formattedAmount
		self.updatePrice = subPrice.formattedAmount

		let subStartDate = Calendar.current.date(byAdding: .year, value: 1, to: Date.now)
		let format = Date.FormatStyle()
			.year(.defaultDigits)
			.month(.wide)

		self.startDate = subStartDate?.formatted(format) ?? "next year"
	}

}

struct CheckoutCustomer: Decodable {
	let name: String
	let email: String
	let subscribe: Bool
}

struct CheckoutIntent: Content {
	let bundleID: String
	let paymentOptions: PaymentOptions

	init?(app: App, price: Price) {
		self.bundleID = app.bundleIdentifier

		guard
			let purchaseAmount = price.unitAmount,
			let currency = price.currency
		else { return nil }

		self.paymentOptions = PaymentOptions(amount: purchaseAmount,
											 currency: currency.rawValue,
											 setupFutureUsage: .offSession)
	}

	struct PaymentOptions: Content {
		var mode: String = "payment"
		let amount: Int
		let currency: String
		let setupFutureUsage: PaymentIntentSetupFutureUsage
	}
}

struct CheckoutReceipt: Content {
	let name: String
	let amount: String
	let sub: Bool
	let showProcessingMessage: Bool
	let receiptURL: String?
}

struct FullReceipt: Content {
	let date: Date
	let totalAmount: String
	let showProcessingMessage: Bool
	let payment: Payment?
	let receiptURL: String?

	let items: [Item]

	struct Item: Content {
		let name: String
		let price: String
		let includesUpdates: Bool
		let updateStartDate: Date?
	}

	struct Payment: Content {
		let brand: String
		let lastFour: String

		init(brand: String, lastFour: String) {
			self.brand = brand
			self.lastFour = lastFour
		}

		init?(_ method: PaymentMethod?) {
			guard
				let brand = method?.card?.brand,
				let lastFour = method?.card?.last4 else {
				return nil
			}

			self.brand = brand.rawValue
			self.lastFour = lastFour
		}
	}
}
