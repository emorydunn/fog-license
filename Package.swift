// swift-tools-version:5.9
import PackageDescription

let package = Package(
	name: "vapor-license",
	platforms: [
		.macOS(.v13)
	],
	products: [
		.library(name: "LicenseModels", targets: ["SharedModels"]),
		.library(name: "FogKit", targets: [
			"FogKit",
			"SharedModels"
		]),
		.library(name: "FogUI", targets: [
			"FogUI",
			"FogKit",
			"SharedModels"
		]),
		.executable(name: "App", targets: ["App"])
	],
	dependencies: [
		// 💧 A server-side Swift web framework.
		.package(url: "https://github.com/vapor/vapor.git", from: "4.83.1"),
		// 🗄 An ORM for SQL and NoSQL databases.
		.package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
		// 🪶 Fluent driver for SQLite.
		.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
		// 🍃 An expressive, performant, and extensible templating language built for Swift.
		.package(url: "https://github.com/vapor/leaf.git", from: "4.2.4"),
		// 💳 Stripe Payments
		.package(url: "https://github.com/vapor-community/stripe-kit.git", from: "22.0.0"),
		.package(path: "/Users/emorydunn/Repositories/personal-libs/ByteKit"),
		.package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
		.package(url: "https://github.com/vapor/jwt-kit.git", from: "4.0.0"),
	],
	targets: [
		.target(name: "SharedModels",
				dependencies: [
					"ByteKit",
					.product(name: "JWTKit", package: "jwt-kit"),
				]),

		.testTarget(name: "ModelTests", dependencies: ["SharedModels"]),

		.target(name: "FogKit", dependencies: [
			"SharedModels",
			.product(name: "JWTKit", package: "jwt-kit"),
		]),

		.target(name: "FogUI", dependencies: [
			"SharedModels",
			"FogKit"
		]),

		.executableTarget(
			name: "App",
			dependencies: [
				.product(name: "Fluent", package: "fluent"),
				.product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
				.product(name: "Leaf", package: "leaf"),
				.product(name: "Vapor", package: "vapor"),
				.product(name: "StripeKit", package: "stripe-kit"),
				.product(name: "JWT", package: "jwt"),
				"ByteKit",
				"SharedModels"
			]
		),
		.testTarget(name: "AppTests", dependencies: [
			.target(name: "App"),
			.product(name: "XCTVapor", package: "vapor"),

			// Workaround for https://github.com/apple/swift-package-manager/issues/6940
			.product(name: "Vapor", package: "vapor"),
			.product(name: "Fluent", package: "Fluent"),
			.product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
			.product(name: "Leaf", package: "leaf"),
		])
	]
)
