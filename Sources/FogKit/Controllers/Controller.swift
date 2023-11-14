//
//  EndpointController.swift
//
//
//  Created by Emory Dunn on 11/7/23.
//

import Foundation
import JWTKit

protocol EndpointController {
	var client: FogClient { get }

	var endpointURL: URL { get }
}

extension EndpointController {
	var session: URLSession { client.session }

	var encoder: JSONEncoder { client.encoder }

	var decoder: JSONDecoder { client.decoder }

	var signer: JWTSigner { client.signer }
}
