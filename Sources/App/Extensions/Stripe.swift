//
//  File.swift
//  
//
//  Created by Emory Dunn on 10/12/23.
//

import Foundation
import StripeKit

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
