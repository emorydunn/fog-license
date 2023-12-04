# Fog License

`fog-license` is a server & framework for managing software licensing and subscriptions. A core feature of the licensing model is an initial purchase plus an ongoing subscription, how this is used is up to the application developer.

The server and its associated frameworks are still very much in development and should probably not be used by anyone.

## Licensing

The licensing model is designed to be flexible. A single license can be activated on any number of computers, configurable per application, and the computer profile can be shared between applications. The goal is to allow many computers to be licensed but allow activation state to be easily moved if a user has more computers than seats.

## The License Code

The license code is designed to be easy to enter by a user. Each code is a four byte sequence represented as a single 32-bit number. There are two special bytes that allow for a quick offline validity test. In theory the sequence can be extended to any length if needed.

0. The App ID
1. Random 8-bit number
2. Random 8-bit number within a clamped range
3. Random 8-bit number

## Activation

A license code is activated for a whole computer, not per user account, and is identified by a hashed version of the computer's unique ID and serial number. The computer is shared across all application activations, allowing for a unified management page to be built.

The server uses JSON Web Tokens as the means of validating & expiring activations.

1. User submits license code to activation a computer
2. Server validates the license
   1. Check if the license is active
   2. Check activation count is under the limit
   3. Check request bundle ID matches app bundle ID
   4. Check license code is valid
3. Server generates a `SignedVerification` which is stored by the application.

On the client side the `SignedVerification` is used to control access to the application. When it expires, by default 5 days, the application must verify itself with the server again.

### Activation States

An application can be in one of three states:

1. Inactive
2. Licensed
3. Activated

A user can deactivate a license without removing it from the machine, this is the difference between `licensed` and `activated`. This allows a user to easily "move" seats between computers without needing to go through the entire licensing process again, it's simply a matter of toggling a particular computer on and off.

Combined with the expiration of an verification computers can remotely deactivated. When the local verification expires the application will attempt to verify the license and, if there are no open seats, fall back to being `licensed`.

## Checkout

The server includes a simple checkout page for each application that showing pricing information and collects payment info.

1. Request a checkout info for the purchase
2. User submits payment info
3. Server creates a customer, payment intent, and receipt
4. For each application a license code is generated and a subscription created, if requested
5. User is redirected to the receipt page
6. Stripe sends a `payment_intent.succeeded` web hook which activates the license

# SwiftUI

The `FogUI` library contains prebuilt views to manage an applications licensing. Configuring an app to be licensed is fairly straight forward.

```swift
import SwiftUI
import FogKit
import FogUI


struct MyCoolApp: App {

    // Create the client pointing to your server
    var client = FogClient(server: URL(string: "http://localhost:8080")!)

    // Create an empty product, it will be updated automatically based on the bundle identifier
    var product = FogProduct()

   var body: some Scene {

       WindowGroup {
           ContentView()
            .environmentObject(product)
            .environment(\.client, client)
            .onAppear {
                   // Refresh the product
                   if product.isStale {
                       product.refresh(using: client)
                   }

                   try? product.storeActivation()
               }
       }

   }

}
```

Now that the environment is set up you can build the rest of your application. Any controls that need to be activation locked can be disabled using the `.activationLocked()` view modifier:

```swift
Button("Export") { }
    .activationLocked() // disabled if activation state is not `activated`
```

The framework also includes a view to handle license activation and management, just add a window to your app's main Scene:

```swift
    var body: some Scene {

        ...

        /// The standard licensing window
        Window(Text("License"), id: "license") {
            LicenseView()
                .environmentObject(product) // Set the product in the environment
                .environment(\.client, client) // Set the client in the environment
        }

    }
```

This view presents a text field for the user to enter a license code & information collected about their computer. After activation shows the license info & license management controls.
