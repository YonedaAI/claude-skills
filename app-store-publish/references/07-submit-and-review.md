# Phase 7 — Submit + review

Last phase. One manual step (IAP product creation in App Store Connect), then fastlane drives the rest.

## The one manual step: IAP product in App Store Connect

Fastlane's modern `connect_api` module doesn't expose IAP creation. The legacy `Spaceship::Tunes` path requires an Apple ID password (not a JWT key) and is fragile. No community plugin works reliably. Keep this one manual.

### Click path

1. https://appstoreconnect.apple.com/apps → select `{{APP_NAME}}`
2. Sidebar: **Monetization → In-App Purchases**
3. **Create +** → select type:
   - **Non-Consumable** — one-time unlock that persists across installs (recommended for most IAPs)
   - **Consumable** — bought and used up (gem/coin packs)
   - **Auto-Renewable Subscription** — recurring
   - **Non-Renewing Subscription** — fixed-period, one-time
4. Fill in:
   - **Reference Name**: `{{FEATURE_NAME}}` (internal, visible only in reports)
   - **Product ID**: `{{IAP_PRODUCT_ID}}` — **must match** what the app's code references (`PurchaseManager.productID`)
   - **Cleared for Sale**: Yes (unless staging)
   - **Price Schedule**: choose tier. Apple's tiers approximate round dollars:
     - Tier 1 = $0.99 / €0.99
     - Tier 3 = $2.99
     - Tier 5 = $4.99 ← common "unlock" price
     - Tier 10 = $9.99
   - **Localization (en-US)**:
     - **Display Name**: what appears in the purchase sheet (≤30 chars). "`{{FEATURE_NAME}}`"
     - **Description**: purchase sheet body (≤45 words). Describe what they get.
   - **Review Information**:
     - **Review Screenshot**: the 640×920+ PNG you saved to `fastlane/metadata/review_information/iap_review_screenshot.png`
     - **Review Notes**: how to access the IAP in the app. Example:
       > In Settings → Sync tab, click "Unlock iCloud Sync". Sandbox tester purchases complete the flow; the app will prompt to quit and relaunch, after which iCloud Sync becomes active. "Restore Purchases" button is in the same pane.
5. Save. The product goes into "Ready to Submit" state.

## Submission

Before submitting, verify:

- IAP product is "Ready to Submit" (or in a later state).
- `fastlane/metadata/` is populated with real content (no "Lorem ipsum").
- Support, marketing, privacy URLs all resolve to live HTTPS pages.
- Screenshots are populated in `fastlane/screenshots/en-US/` and are the right dimensions.
- `project.yml` has `ITSAppUsesNonExemptEncryption: false` (or you've filled in the encryption declaration).
- `CFBundleShortVersionString` is higher than the last-approved version (or the app is 1.0).

Run:

```sh
bundle exec fastlane mac mas_release
```

What happens:

1. **`mas_build`** — archives and exports `build/mas/{{APP_NAME}}.pkg`.
2. **`upload_to_app_store`** (via altool/Transporter):
   - Uploads the `.pkg` → App Store Connect processes it (5–30 min).
   - Uploads metadata from `fastlane/metadata/`.
   - Uploads screenshots from `fastlane/screenshots/`.
   - Links the binary to the App Store version (e.g. 1.0) when processing completes.
3. **Submits for review** — with `submit_for_review: true`, `automatic_release: false` (manual release when approved).

## Review timeline

- **First submission with IAP**: 24h–7d. Apple reviews the app binary and the IAP product together.
- **Subsequent versions**: usually <24h if no IAP changes; a few days if adding/changing IAPs.
- **Rejection categories** (most common for utilities):
  - 2.1 Performance — app crashes during reviewer's test.
  - 2.3 Accurate Metadata — screenshots don't match app behavior.
  - 3.1.1 In-App Purchase — Restore missing, paywall wording misleading.
  - 4.0 Design — core feature broken.
  - 5.1 Privacy — missing privacy URL, app collects data not disclosed in App Privacy.

## If rejected

1. Read Resolution Center message carefully.
2. Reply with clarification if you disagree (Apple does reverse rejections).
3. Or fix and resubmit — usually a same-day cycle.
4. Binary rejections need a new upload (bump `CFBundleVersion`). Metadata-only rejections can be fixed in App Store Connect without a new binary.

## After approval

State in App Store Connect goes to "Pending Developer Release" (since we set `automatic_release: false`).

Options:
- Click "Release This Version" when ready — app goes live within 24h.
- Or "Automatically Release" from App Store Connect directly.
- Or schedule a date.

## Post-release housekeeping

- `git tag v{{VERSION}}` the commit that produced the submitted binary.
- Update `fastlane/metadata/en-US/release_notes.txt` for the next version.
- If the app has a website, update download links.
- Archive `build/mas/` artifacts somewhere durable — you may need them for support ("user reports crash on v1.0.0; what's in that binary?").
