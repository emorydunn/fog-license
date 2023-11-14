//
//  Preview App.swift
//  License Manager
//
//  Created by Emory Dunn on 10/29/23.
//

import Foundation
import SharedModels

#if DEBUG
public extension AppInfo {
	static let preview = AppInfo(name: "Test App",
								 bundleIdentifier: "com.test.app",
								 purchase: PurchaseInfo(id: "price_1234", amount: 1234),
								 subscription: nil,
								 number: 1,
								 activationCount: 3,
								 licenseCount: 123,
								 subscriberCount: 42)
}

public extension SignedVerification {
	static let preview = SignedVerification(bundleIdentifier: "com.test.app",
										  expiration: Date(timeIntervalSinceNow: 259200), // 3 days
										  licenseCode: 123456,
										  hardwareIdentifier: "fake_hardware")
}

public extension SoftwareLicense {
	static let preview = SoftwareLicense(code: 5432,
										 name: "Test App",
										 bundleIdentifier: "com.test.app",
										 customerName: "Test Customer",
										 customerEmail: "test@test.com",
										 activationDate: Date(),
										 expiryDate: Date(timeIntervalSinceNow: 187200),
										 isActive: true,
										 hasSubscription: true,
										 activationLimit: 3,
										 activationCount: 3)
}
#endif
