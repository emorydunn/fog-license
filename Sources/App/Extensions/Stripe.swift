//
//  File.swift
//  
//
//  Created by Emory Dunn on 10/12/23.
//

import Foundation
import StripeKit
import Vapor

extension Price {
	var formattedAmount: String {

		guard
			let unitAmount,
			let currency
		else { return "error" }

		let string = (unitAmount / 100).formatted(.currency(code: currency.rawValue))

		switch type {
		case .oneTime:
			return string
		case .recurring:
			break
		case nil:
			return string
		}

		guard let interval = self.recurring?.interval else {
			return string
		}

		return "\(string)/\(interval)"
	}

}

extension PaymentIntent {
	var createSubscription: Bool {
		metadata?["create_subscription"] == "true"
	}

	var formattedAmount: String {
		guard
			let amount,
			let currency 
		else {
			return String(describing: amount)
		}

		return (amount / 100).formatted(.currency(code: currency.rawValue))
	}

	var statusMessage: String {
		switch status {
		case .none:
			return ""
		case .succeeded:
			return "Payment succeeded!"
		case .processing:
			return "Your payment is processing."
		case .canceled:
			return "The payment was cancelled."
		case .requiresPaymentMethod:
			return "Your payment was not successful, please try again."

		default:
			return "Something went wrong."
		}
	}
}

extension StripeClient {
	func createPaymentIntent(by user: User, for app: App) async throws -> PaymentIntent {
		let purchasePrice = try await prices.retrieve(price: app.purchaseID, expand: nil)

			return try await paymentIntents.create(amount: purchasePrice.unitAmount!,
														 currency: .usd,
														 automaticPaymentMethods: ["enabled": true],
														 confirm: nil,
														 customer: user.externalID,
														 description: purchasePrice.nickname,
														 metadata: nil,
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

	}

	func createPaymentIntent(by user: User, for purchasePrice: Price) async throws -> PaymentIntent {
		return try await paymentIntents.create(amount: purchasePrice.unitAmount!,
											   currency: .usd,
											   automaticPaymentMethods: ["enabled": true],
											   confirm: nil,
											   customer: user.externalID,
											   description: purchasePrice.nickname,
											   metadata: nil,
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

	}


}

extension StripeError: DebuggableError {
	public var identifier: String {
		return error?.type?.rawValue ?? "Unknown Error"
	}
	
	public var reason: String {
		return error?.message ?? "Unknown Error"
	}
	
}
