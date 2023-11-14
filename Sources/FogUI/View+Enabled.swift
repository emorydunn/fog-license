//
//  View+Enabled.swift
//  License Manager
//
//  Created by Emory Dunn on 11/4/23.
//

import Foundation
import SwiftUI
import FogKit

struct ActivationLock: ViewModifier {

	@EnvironmentObject var product: FogProduct

	func body(content: Content) -> some View {
		content
			.enabled(product.activationSate.isActivated)
	}

}

public extension View {
	/// Adds a condition that controls whether users can interact with this view.
	/// - Parameter enabled: A Boolean value that determines whether users can interact with this view.
	/// - Returns: A view that controls whether users can interact with this view.
	func enabled(_ enabled: Bool) -> some View {
		disabled(!enabled)
	}
	
	/// Disable this view if the product is not activated.
	/// - Returns: A view that controls whether users can interact with this view. 
	func activationLocked() -> some View {
		modifier(ActivationLock())
	}
}
