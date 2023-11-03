//
//  File.swift
//  
//
//  Created by Emory Dunn on 10/29/23.
//

import Foundation
//import Vapor
//import Fluent
//import StripeKit

public struct AppInfo: Codable, Identifiable, Comparable, Hashable {

	public var id: String { bundleIdentifier }

	public var name: String
	public var bundleIdentifier: String
	public var purchase: PurchaseInfo
	public var subscription: SubscriptionInfo?

	public let number: UInt8
	public var activationCount: Int

	public let licenseCount: Int
	public let subscriberCount: Int

	public var iconPath: String {
		"/images/\(bundleIdentifier).png"
	}

	public init(name: String, bundleIdentifier: String, purchase: PurchaseInfo, subscription: SubscriptionInfo? = nil, number: UInt8, activationCount: Int, licenseCount: Int, subscriberCount: Int) {
		self.name = name
		self.bundleIdentifier = bundleIdentifier
		self.purchase = purchase
		self.subscription = subscription
		self.number = number
		self.activationCount = activationCount
		self.licenseCount = licenseCount
		self.subscriberCount = subscriberCount
	}

	public static func < (lhs: AppInfo, rhs: AppInfo) -> Bool {
		lhs.name.localizedCompare(rhs.name) == .orderedAscending
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(name)
		hasher.combine(bundleIdentifier)
	}

}

public struct PurchaseInfo: Codable, Identifiable, Equatable, Hashable {
	public var id: String
	public let amount: Int

	public init(id: String, amount: Int) {
		self.id = id
		self.amount = amount
	}

	public var dollarAmount: Int { amount / 100 }
}

public struct SubscriptionInfo: Codable, Identifiable, Equatable, Hashable {
	public var id: String
	public let amount: Int
	public let period: SubscriptionInterval

	public init(id: String, amount: Int, period: SubscriptionInterval) {
		self.id = id
		self.amount = amount
		self.period = period
	}

	public var dollarAmount: Int { amount / 100 }
}

public enum SubscriptionInterval: String, Codable, Equatable, Hashable {
	case year
	case month
	case week
	case day
}
