//
//  File.swift
//  
//
//  Created by Emory Dunn on 10/12/23.
//

import Foundation
import SystemConfiguration
import IOKit
import CryptoKit

struct HardwareIdentifier: Hashable, Encodable {
	let serialNumber: String
	let uuid: UUID
	let computerName: String
	let computerModel: String
	let osVersion: String

	init?() {
		guard
			let serialNumber = HardwareIdentifier.serialNumber(),
			let uuid = HardwareIdentifier.uniqueID(),
			let computerName = SCDynamicStoreCopyComputerName(nil, nil) as? String
		else {
			return nil
		}
		self.serialNumber = serialNumber
		self.uuid = uuid
		self.computerName = computerName
		self.computerModel = HardwareIdentifier.model()


		let osVersion = ProcessInfo.processInfo.operatingSystemVersion
		self.osVersion = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

	}

	enum CodingKeys: CodingKey {
		case computerName
		case computerModel
		case osVersion
		case digest
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(self.computerName, forKey: .computerName)
		try container.encode(self.computerModel, forKey: .computerModel)
		try container.encode(self.osVersion, forKey: .osVersion)

		let digest = Data(secureHash())
		try container.encode(digest, forKey: .digest)
	}

	func secureHash() -> SHA256.Digest {
		let serialData = Data(serialNumber.utf8)
		let idData = Data(uuid.data)

		var hardwareData = Data()

		hardwareData.append(contentsOf: serialData)
		hardwareData.append(contentsOf: idData)

		return SHA256.hash(data: hardwareData)
	}

	static func property(for key: String) -> Any? {
		let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

		let property = IORegistryEntryCreateCFProperty(platformExpert, key as CFString, kCFAllocatorDefault, 0)

		IOObjectRelease(platformExpert)

		return property?.takeUnretainedValue()
	}

	static func property<P>(for key: String) -> P? {
		property(for: key) as? P
	}

	static func serialNumber() -> String? {
		return property(for: kIOPlatformSerialNumberKey)
	}

	static func uniqueID() -> UUID? {
		guard let uuidString: String = property(for: kIOPlatformUUIDKey) else { return nil }

		return UUID(uuidString: uuidString)
	}

	static func model() -> String {
		var length = 0
		sysctlbyname("hw.model", nil, &length, nil, 0)
		var cpuModel = [CChar](repeating: 0, count: length)
		sysctlbyname("hw.model", &cpuModel, &length, nil, 0)
		return String(cString: cpuModel)
	}
}

public extension UUID {
	var data: Data {
		var result = Data()
		result.append(uuid.0)
		result.append(uuid.1)
		result.append(uuid.2)
		result.append(uuid.3)
		result.append(uuid.4)
		result.append(uuid.5)
		result.append(uuid.6)
		result.append(uuid.7)
		result.append(uuid.8)
		result.append(uuid.9)
		result.append(uuid.10)
		result.append(uuid.11)
		result.append(uuid.12)
		result.append(uuid.13)
		result.append(uuid.14)
		result.append(uuid.15)
		return result
	}
}
