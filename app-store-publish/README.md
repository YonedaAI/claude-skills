# app-store-publish

Generic Mac App Store publishing pipeline for SwiftUI apps. Extracted from a real production release (Copied App by Magneton Labs) and rewritten as reusable skill + references.

Covers:

1. **Prerequisites** — Apple Developer enrollment, App Store Connect app record, API key generation.
2. **Fastlane setup** — Gemfile, `.env` + `.keys/` layout, `asc_api_key` helper that references the `.p8` by path (private key never leaves disk).
3. **Certs + profiles** — single `mas_setup` lane that creates Apple Distribution cert + Mac Installer Distribution cert + Mac App Store provisioning profile via the App Store Connect API. Documents the gotchas (Admin-role requirement, `cert_id` pinning, filename extension).
4. **Sandbox entitlements** — MAS vs Developer ID split, CloudKit under sandbox, local-launch blocking (AMFI), dev-signed "mas_debug_build" lane for sandbox compatibility testing without TestFlight round-trip.
5. **IAP integration** — StoreKit 2 `PurchaseManager` pattern, SwiftData CloudKit's boot-time constraint, restart-prompt UX, `Transaction.updates` listener, debug-only reconciliation bypass for local flag testing.
6. **Metadata + screenshots** — `fastlane/metadata/` directory layout, required `.txt` files, Retina-native screenshot capture via `screencapture` + `sips` resize.
7. **Submit** — `mas_release` lane, review notes template, the one genuinely-manual step (IAP product creation in App Store Connect web UI).

## Usage

Invoke the skill via slash command or reference directly:

```
/app-store-publish
```

The skill reads your app's `{{APP_NAME}}`, `{{BUNDLE_ID}}`, `{{TEAM_ID}}`, `{{ICLOUD_CONTAINER}}`, `{{IAP_PRODUCT_ID}}` from project state or prompts for them, then walks you through each phase, delegating to the reference docs for deep dives and to the template files for scaffolded configs.

## Template files

`templates/` contains drop-in configs that work with placeholder substitution:

- `Fastfile.template` — all the lanes (`mas_setup`, `mas_build`, `mas_debug_build`, `mas_release`)
- `project.yml.template` — XcodeGen project config (two entitlement files, scheme StoreKit wiring)
- `CopiedMac-MAS.entitlements.template` — sandboxed variant
- `PurchaseManager.swift.template` — StoreKit 2 wrapper
- `Copied.storekit.template` — local purchase simulation

## Why this exists

Shipping a sandboxed macOS app with IAP to the Mac App Store involves ~15 non-obvious gotchas across Apple's tooling, fastlane's opinions, and SwiftData's quirks. This plugin captures them all in one place so the next app takes an afternoon, not a week.
