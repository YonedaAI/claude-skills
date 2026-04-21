# Phase 5 — StoreKit 2 IAP integration

Skip this phase if the app has no in-app purchase. If monetizing with a one-time unlock (non-consumable) gating a feature (sync, export, advanced mode), this is the pattern.

## The architecture

Three pieces:

1. **`PurchaseManager`** — `@Observable @MainActor` singleton wrapping StoreKit 2. Handles product fetch, purchase, restore, entitlement reconciliation, and the `Transaction.updates` listener.
2. **Feature gate** — wherever the paid feature initializes. Reads a UserDefaults flag synchronously at app launch for boot-time decisions (e.g. SwiftData CloudKit config).
3. **Settings UI** — unlock CTA + Restore Purchases button (Apple Review 3.1.1 mandates Restore).

## Compile flag split

Wrap all IAP code in `#if MAS_BUILD`. The MAS fastlane lanes set `SWIFT_ACTIVE_COMPILATION_CONDITIONS='MAS_BUILD'`. Developer ID builds don't link StoreKit. This keeps the OSS code path clean and avoids shipping a paywall to direct-download users.

## PurchaseManager pattern

See `templates/PurchaseManager.swift.template` for the full file. Key elements:

```swift
#if MAS_BUILD
import Foundation
import StoreKit
import Observation

@Observable
@MainActor
public final class PurchaseManager {
    public static let shared = PurchaseManager()

    nonisolated public static let productID = "{{IAP_PRODUCT_ID}}"
    nonisolated public static let purchasedKey = "{{FEATURE}}Purchased"

    public private(set) var product: Product?
    public var isPremium: Bool {
        UserDefaults.standard.bool(forKey: Self.purchasedKey)
    }
    public private(set) var purchaseInFlight = false
    public private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()
        #if DEBUG
        // Dev-only: set `_skipStoreKitReconcile=YES` in the app's prefs to
        // keep a manually-flipped flag. Lets paid state be tested without
        // Xcode's StoreKit Test harness attached (needed for direct-launch builds).
        if !UserDefaults.standard.bool(forKey: "_skipStoreKitReconcile") {
            Task { await refreshEntitlements() }
        }
        #else
        Task { await refreshEntitlements() }
        #endif
        Task { await loadProduct() }
    }

    public func loadProduct() async { /* Product.products(for: [productID]) */ }
    @discardableResult public func purchase() async -> Bool { /* product.purchase() */ }
    @discardableResult public func restore() async -> Bool { /* AppStore.sync() + refresh */ }
    public func refreshEntitlements() async { /* iterate Transaction.currentEntitlements */ }

    private func setPremium(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.purchasedKey)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.productID else { continue }
                await MainActor.run {
                    self?.setPremium(transaction.revocationDate == nil)
                }
                await transaction.finish()
            }
        }
    }
}
#endif
```

### Why `nonisolated` on the static constants

`@MainActor` on the class makes all static members MainActor-isolated by default. Gate code at the container init needs to reference the key synchronously — mark the constants `nonisolated` so non-isolated contexts can read them.

### Why cache in UserDefaults

`Transaction.currentEntitlements` is async. Your `ModelContainer` initializer at app launch is sync. The UserDefaults cache bridges them: on purchase, flag is written; on app launch, container reads cached flag; PurchaseManager re-verifies async in parallel.

### Why no `deinit`

Swift 6 strict concurrency rejects accessing `@MainActor`-isolated stored properties from `deinit` (nonisolated context). Since this is a singleton with app lifetime, the listener task lives until process exit. No cleanup needed.

### Debug-only reconcile bypass

The default behavior on launch is to hit StoreKit, get `Transaction.currentEntitlements`, and update the cached flag. This makes manual `defaults write iCloudSyncPurchased -bool YES` useless for testing — the reconcile wipes it back to false.

In DEBUG builds, the `_skipStoreKitReconcile` UserDefault bypass lets you:
1. `defaults write <container>.plist _skipStoreKitReconcile -bool YES`
2. `defaults write <container>.plist {{FEATURE}}Purchased -bool YES`
3. Relaunch → paid state active, gate verified, no Xcode harness needed.

Release builds don't compile this bypass.

## The gate

At the `ModelContainer` (or whatever resource the IAP gates) init site:

```swift
enum SharedData {
    @MainActor
    static let container: ModelContainer = {
        let userToggle = UserDefaults.standard.object(forKey: "{{FEATURE}}Enabled") as? Bool ?? true
        #if MAS_BUILD
        let purchased = UserDefaults.standard.bool(forKey: "{{FEATURE}}Purchased")
        let featureEnabled = userToggle && purchased
        #else
        let featureEnabled = userToggle
        #endif
        // ... configure container based on featureEnabled
    }()
}
```

## Restart prompt UX

SwiftData's `ModelContainer` CloudKit configuration is **boot-time only**. You cannot flip CloudKit on mid-session. After a successful purchase:

```swift
if await PurchaseManager.shared.purchase() {
    showRestartAlert = true
    // alert has "Quit {{APP_NAME}}" button that calls NSApplication.shared.terminate(nil)
}
```

Users expect this pattern — it's standard for sandboxed macOS apps gating boot-time config.

## Settings UI

Under `#if MAS_BUILD` in the Sync tab (or wherever):

```swift
if !iCloudSyncPurchased {
    VStack(alignment: .leading) {
        HStack {
            Image(systemName: "lock.icloud")
            Text("Sync is locked")
        }
        HStack {
            Button {
                Task {
                    if await PurchaseManager.shared.purchase() {
                        showRestartAlert = true
                    }
                }
            } label: {
                if let price = PurchaseManager.shared.product?.displayPrice {
                    Text("Unlock iCloud Sync — \(price)")
                } else {
                    Text("Unlock iCloud Sync")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(PurchaseManager.shared.purchaseInFlight
                      || PurchaseManager.shared.product == nil)

            Button("Restore Purchases") {
                Task { _ = await PurchaseManager.shared.restore() }
            }
            .buttonStyle(.bordered)
        }
    }
    .task { await PurchaseManager.shared.loadProduct() }
}
```

The "Restore Purchases" button is mandatory per App Review Guideline 3.1.1. Omitting it is an auto-reject.

## Copied.storekit file

For local testing in Xcode without App Store Connect round-trips:

```json
{
  "identifier" : "<random UUID>",
  "nonRenewingSubscriptions" : [],
  "products" : [
    {
      "displayPrice" : "4.99",
      "familyShareable" : false,
      "internalID" : "LocalTestProduct",
      "localizations" : [
        {
          "description" : "{{DESCRIPTION}}",
          "displayName" : "{{FEATURE_NAME}}",
          "locale" : "en_US"
        }
      ],
      "productID" : "{{IAP_PRODUCT_ID}}",
      "referenceName" : "{{FEATURE_NAME}}",
      "type" : "NonConsumable"
    }
  ],
  "settings" : {
    "_developerTeamID" : "{{TEAM_ID}}",
    "_failTransactionsEnabled" : false,
    "_locale" : "en_US",
    "_storefront" : "USA"
  },
  "subscriptionGroups" : [],
  "version" : { "major" : 3, "minor" : 0 }
}
```

Wire to the scheme via `project.yml`:

```yaml
targets:
  {{APP_NAME}}:
    scheme:
      storeKitConfiguration: {{APP_NAME}}.storekit
```

After `xcodegen generate`, the shared `.xcscheme` under `Copied.xcodeproj/xcshareddata/xcschemes/` contains `<StoreKitConfigurationFileReference identifier="../../Copied.storekit">`.

**Important**: the StoreKit config only activates when launched from **Xcode's Run button**. `open build/.../MyApp.app` doesn't use it. So the workflow for full IAP testing is:

1. Open project in Xcode.
2. Run scheme (CopiedMac).
3. Attempt purchase — Xcode's simulated StoreKit sheet appears.
4. Approve → transaction flows through PurchaseManager → premium flag set.
5. Debug → StoreKit → Manage Transactions to inspect/refund.

## App Review considerations

Review notes (in `fastlane/metadata/review_information/notes.txt`) should explicitly explain:

- The IAP product ID and price.
- Which feature it unlocks.
- What users can do without purchasing (typically: keep using the free features — local mode).
- Step-by-step test instructions for the reviewer.
- That "Restore Purchases" exists.

Apple reviewers use a sandbox tester account they control. They'll click through the purchase flow and verify the feature works. If you hide Restore, reject. If purchase is flaky, reject. If the IAP isn't clearly testable, reject.
