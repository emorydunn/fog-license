//
//  File.swift
//  
//
//  Created by Emory Dunn on 11/1/23.
//

import Foundation
import Vapor
import Fluent

final class TrialLicense: Model, Content {
	static let schema = "trial_license"

	@ID(key: .id)
	var id: UUID?

	@Timestamp(key: "start_date", on: .create)
	var startDate: Date?

	@Field(key: "duration")
	var duration: TimeInterval

	@Parent(key: "application_id")
	var application: App

	@Parent(key: "computer_id")
	var computer: ComputerInfo
}
