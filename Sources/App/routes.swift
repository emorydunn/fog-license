import Vapor

func routes(_ app: Application) throws {

	try app.group("api", "v1") { group in
		try group.register(collection: AppController())
		try group.register(collection: UserController())
		try group.register(collection: ReceiptController())
	}

	try app.register(collection: WebhookController())
	try app.register(collection: CheckoutController())

}
