//
//  File.swift
//  
//
//  Created by Emory Dunn on 11/9/23.
//

import Foundation
import SwiftUI
import FogKit

public struct EnvClient: EnvironmentKey {
	public static var defaultValue: FogClient = FogClient(server: URL(string: "defaultHost")!, signer: .unsecuredNone)
}

@available(macOS 14.0, *)
public struct EnvAppManager: EnvironmentKey {
	public static var defaultValue = AppManager()
}

public extension EnvironmentValues {
	var client: FogClient {
		get {
			self[EnvClient.self]
		}
		set {
			self[EnvClient.self] = newValue
		}
	}

	@available(macOS 14.0, *)
	var appManager: AppManager {
		get {
			self[EnvAppManager.self]
		}
		set {
			self[EnvAppManager.self] = newValue
		}
	}
}
