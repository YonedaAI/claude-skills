---
name: app-store-publish
description: End-to-end Mac App Store publishing for a macOS SwiftUI app. Walks through fastlane setup, cert/profile provisioning via API, sandboxed builds, optional StoreKit 2 IAP integration, screenshots, metadata, and review submission. Use when user asks to "publish to App Store", "ship to Mac App Store", "submit for review", "set up fastlane for macOS", or wants to add IAP to a sandboxed Mac app.
---

# app-store-publish

Ships a macOS SwiftUI app to the Mac App Store with optional StoreKit 2 in-app purchase gating. Assumes you have a working Developer ID pipeline (or can tolerate a parallel one) and want to add a MAS variant.

## Orchestration

The skill walks through seven phases. Each phase has a dedicated reference file with the full details; the skill's job is to track progress and keep the user moving.

### Phase 0 — gather project identifiers

Before any setup, collect:

- `{{APP_NAME}}` — display name (e.g. "My App")
- `{{BUNDLE_ID}}` — e.g. `com.example.myapp`
- `{{TEAM_ID}}` — 10-char Apple Team ID (find in Apple Developer → Membership, or via `security find-identity -v -p codesigning`)
- `{{ICLOUD_CONTAINER}}` — only if using CloudKit, e.g. `iCloud.com.example.myapp`
- `{{IAP_PRODUCT_ID}}` — only if gating features behind an IAP, e.g. `com.example.myapp.pro` or `com.example.myapp.icloud_sync`
- `{{APP_STORE_APP_NAME}}` — the App Store listing name (App Store enforces name uniqueness; may differ from `{{APP_NAME}}`)

Check if any are already set (look at `project.yml`, `Info.plist`, entitlements). Ask for missing ones.

### Phase 1 — Prerequisites (manual, one-time)

See `references/01-prerequisites.md`.

- Confirm Apple Developer enrollment is active.
- Confirm an App record exists in App Store Connect — it can be in "Prepare for Submission" state.
- Generate an App Store Connect API key with **Admin** role (required for cert creation). Download the `.p8`.
- Verify cert state in Keychain with `security find-identity -v -p codesigning` — you'll need Apple Development and Apple Distribution, plus 3rd Party Mac Developer Installer for MAS.

Don't proceed until the `.p8` is downloaded.

### Phase 2 — Fastlane setup

See `references/02-fastlane-setup.md`. Use `templates/Fastfile.template` and `templates/.env.example`.

Steps:

1. Create `Gemfile` with `fastlane` + `dotenv`. Run `bundle install --path vendor/bundle`.
2. Create `.keys/` dir at repo root. Move the `.p8` there. Do **not** commit.
3. Create `.env` at repo root with `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_PATH`. Check in `.env.example` (no real values).
4. Drop the `Fastfile.template` into `fastlane/Fastfile`, substitute `{{TEAM_ID}}`, `{{BUNDLE_ID}}`, `{{APP_STORE_PROVISIONING_PROFILE_NAME}}` (conventional: `{{APP_NAME}} Mac MAS`).
5. Add to `.gitignore`: `.keys/`, `.env`, `*.p8`, `vendor/bundle/`, `.bundle/`.

### Phase 3 — Certs + provisioning profile via API

See `references/03-certs-and-profiles.md`.

Run `bundle exec fastlane mac mas_setup`. It creates (or reuses existing):

- Apple Distribution cert (signs the `.app`)
- 3rd Party Mac Developer Installer cert (signs the `.pkg`)
- Mac App Store provisioning profile bound to `{{BUNDLE_ID}}`

**Gotchas** — if mas_setup fails read the error and check:

- `"You do not have permission to create this certificate"` → API key needs Admin role.
- `"Could not find option 'app_store'"` → macOS doesn't accept `app_store: true`; remove it (macOS default = App Store when no other flag set).
- `"filename must end with .mobileprovision"` → drop the custom `filename:` arg, let fastlane name it.
- `"Could not find a matching code signing identity for type 'AppStore'"` → pass `cert_id:` captured from the prior `get_certificates` output.

### Phase 4 — Sandbox entitlements + mas_debug_build

See `references/04-sandbox-entitlements.md`. Use `templates/MAS.entitlements.template`.

MAS requires `com.apple.security.app-sandbox: true`. Direct-download builds typically don't. Keep both:

- `{{APP_NAME}}.entitlements` — current (Developer ID, sandbox off)
- `{{APP_NAME}}-MAS.entitlements` — new (sandbox on, plus CloudKit/app-groups if needed)

Wire into `project.yml` (or Xcode manually) so fastlane lanes can select the right entitlements file.

**AMFI blocks MAS-signed apps from launching locally via `open`.** You cannot test sandbox behavior from a `mas_build` output. Run `mas_debug_build` instead — Apple Development signing + MAS entitlements = sandboxed app that can launch. Verify: menu bar icon, global hotkey, clipboard access, CloudKit sync (if entitled), file permissions.

### Phase 5 — IAP integration (skip if not monetized)

See `references/05-iap-integration.md`. Use `templates/PurchaseManager.swift.template` and `templates/Copied.storekit.template`.

Architecture:

1. **Compile flag split.** Set `SWIFT_ACTIVE_COMPILATION_CONDITIONS=MAS_BUILD` in `mas_build` / `mas_debug_build` lanes. Wrap IAP code in `#if MAS_BUILD`. Developer ID build doesn't link StoreKit.

2. **PurchaseManager** — `@Observable` `@MainActor` singleton:
   - `public static let shared`
   - `nonisolated public static let productID` — product IDs are `nonisolated` so gate code can reference them from sync contexts
   - Cache `isPremium` in `UserDefaults("{{something}}Purchased")` so container init can read it synchronously at boot
   - `listenForTransactions()` with `Task.detached` for `Transaction.updates`
   - `refreshEntitlements()` reconciles on launch
   - Debug-only bypass via `_skipStoreKitReconcile` UserDefault for local testing without Xcode StoreKit harness

3. **CloudKit gate** — at the `ModelContainer` init call site, check the cached premium flag before deciding CloudKit config:
   ```swift
   #if MAS_BUILD
   let enabled = userToggle && UserDefaults.standard.bool(forKey: "{{IAP_PRODUCT}}Purchased")
   #else
   let enabled = userToggle
   #endif
   ```

4. **Restart prompt** — SwiftData's CloudKit config is boot-time only. After successful purchase, show a modal: "Quit and reopen to enable sync." This is the standard UX.

5. **`Copied.storekit`** — drop-in JSON file for in-Xcode simulated purchases. Wire to the scheme via `project.yml` target's `scheme.storeKitConfiguration: Copied.storekit`.

6. **Settings UI** — unlock CTA with "Unlock {{FEATURE}} — $X.XX" button + "Restore Purchases" button. Both mandatory per App Review 3.1.1.

### Phase 6 — Metadata + screenshots

See `references/06-metadata-screenshots.md`.

Metadata lives in `fastlane/metadata/`. Required files:

- `copyright.txt`, `primary_category.txt` (non-localized)
- `en-US/name.txt`, `subtitle.txt`, `description.txt`, `keywords.txt`, `promotional_text.txt`, `release_notes.txt`, `support_url.txt`, `marketing_url.txt`, `privacy_url.txt`
- `review_information/{first_name,last_name,email_address,phone_number,demo_user,demo_password,notes}.txt`

Screenshots go in `fastlane/screenshots/en-US/` as PNGs. Apple accepts 1280×800, 1440×900, 2560×1600, **2880×1800**. Simplest capture on Retina:

```sh
screencapture -x -t png /tmp/shot.png  # yields 2x pixel dims
sips -z 1800 2880 /tmp/shot.png --out fastlane/screenshots/en-US/01_foo.png
```

Upload in filename sort order. Minimum 1 screenshot, max 10.

### Phase 7 — Submit

See `references/07-submit-and-review.md`.

1. **One manual step remains**: create the IAP product in App Store Connect web UI (there's no clean API). `references/07-submit-and-review.md` has the exact click path.
2. Once the IAP product is "Ready to Submit":
   ```sh
   bundle exec fastlane mac mas_release
   ```
   Builds, uploads binary, uploads metadata + screenshots, submits for review with `automatic_release: false`.
3. Watch for processing in App Store Connect (5–30 min).
4. Apple's review takes 24h–7d for a first submission with IAP.

## Progress tracking

When orchestrating, use TodoWrite to track which phase is active. Typical flow:

```
[in_progress] Phase 1 — verify prerequisites
[pending]     Phase 2 — fastlane setup
[pending]     Phase 3 — mas_setup (create certs + profile via API)
[pending]     Phase 4 — sandbox compatibility via mas_debug_build
[pending]     Phase 5 — IAP integration (skip if not monetized)
[pending]     Phase 6 — metadata + screenshots
[pending]     Phase 7 — submit for review
```

Pause between phases for the user to verify visible results (cert appeared in Keychain, build launched correctly, sync works, etc.). Don't batch through without checkpoints — too many things can go wrong silently.
