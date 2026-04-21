# Phase 1 — Prerequisites

Everything Apple-side you need before touching fastlane.

## Apple Developer enrollment

Active Apple Developer Program membership ($99/year). Check status at https://developer.apple.com/account/. If expired, renewal takes 24–48h. Skip the rest until it's active.

## App record in App Store Connect

Create the app at https://appstoreconnect.apple.com/apps/new/app. You need:

- **Platform**: macOS
- **Name**: the display name shown in the App Store (e.g. "My App"). Must be globally unique — if taken, pick a variant. This is `{{APP_STORE_APP_NAME}}`.
- **Primary language**: English (U.S.) is most common.
- **Bundle ID**: create via Apple Developer → Identifiers first. Use `{{BUNDLE_ID}}`, e.g. `com.example.myapp`. If CloudKit-enabled, check "iCloud" and add `{{ICLOUD_CONTAINER}}`.
- **SKU**: internal identifier. Convention: `{{BUNDLE_ID}}` or a human slug.

App record can stay in "Prepare for Submission" state indefinitely — no pressure to submit right after creation.

## App Store Connect API key (Admin role)

Apple uses this to authenticate automated actions. Create at https://appstoreconnect.apple.com/access/integrations/api.

- **Role**: **Admin** — lower roles can't create Distribution certs. This is the single most common cause of `mas_setup` failing with "You do not have permission to create this certificate". You can demote the key after cert creation if you're squeamish.
- **Name**: something descriptive like "Fastlane Admin".
- Download the `.p8` **immediately** — Apple only offers the download once.

Three values you'll need:

- Key ID — visible in the integrations list (e.g. `F2AUJ7JBDK`)
- Issuer ID — at the top of the integrations page, UUID format (e.g. `754aff2c-abb4-47e4-9fd2-080c8e6b3359`)
- The `.p8` file contents (keep on disk only)

## Keychain state

Run:

```sh
security find-identity -v -p codesigning
```

Expected for a Developer ID-only app:
- `Apple Development: <name>` (dev cert for local runs)
- `Developer ID Application: <team>` (direct-distribution signing)
- `Developer ID Installer: <team>` (direct-distribution PKG signing)

What `mas_setup` in Phase 3 will add:
- `Apple Distribution: <team>` (App Store app signing)
- `3rd Party Mac Developer Installer: <team>` (App Store PKG signing)

If you already have these, `mas_setup` reuses them. If not, it creates via the API.

## Xcode + command-line tools

- Xcode 16+ for SwiftUI macOS 15 targets.
- Command Line Tools: `xcode-select --install`.
- XcodeGen (if your project uses it): `brew install xcodegen`.
- Homebrew Ruby isn't strictly required — system Ruby 2.6.10 is fine for fastlane 2.231.x (with Ruby-version warnings). Upgrade when fastlane drops 2.6 support.

## Network checks

Fastlane hits:
- `appstoreconnect.apple.com`
- `developer.apple.com`
- `api.appstoreconnect.apple.com`

If behind corporate proxy or MFA-enforced network, auth flows may silently hang. Run on a clean network first.
