# Phase 6 — Metadata + screenshots

Fastlane's `deliver` uploads everything Apple's web UI would ask for — description, keywords, URLs, screenshots, review info — from a directory tree you populate with `.txt` and `.png` files.

## Directory layout

```
fastlane/metadata/
  copyright.txt                          # non-localized: "2026 <Company>"
  primary_category.txt                   # e.g. MAC_UTILITIES, MAC_PRODUCTIVITY
  primary_first_sub_category.txt         # optional
  primary_second_sub_category.txt        # optional
  en-US/
    name.txt                             # App name as shown on the store (must match App Store Connect)
    subtitle.txt                         # short tagline, ≤30 chars
    description.txt                      # ≤4000 chars, multi-line OK
    keywords.txt                         # comma-separated, ≤100 chars total
    promotional_text.txt                 # ≤170 chars, editable without resubmission
    release_notes.txt                    # "What's New" for this version
    support_url.txt                      # required, https://
    marketing_url.txt                    # optional, https://
    privacy_url.txt                      # required since 2018
  review_information/
    first_name.txt
    last_name.txt
    email_address.txt                    # Apple reviewer contact
    phone_number.txt                     # +1 XXX XXX XXXX format, real number
    demo_user.txt                        # if app has login, else empty
    demo_password.txt                    # if app has login, else empty
    notes.txt                            # free-form notes to reviewer
fastlane/screenshots/
  en-US/
    01_main.png
    02_feature.png
    ... (up to 10)
```

## `.txt` content rules

- **`name.txt`**: must equal the App Name set in App Store Connect. Mismatch → deliver errors out.
- **`subtitle.txt`**: shown under the name on the store. ≤30 chars. Optional but recommended.
- **`description.txt`**: up to 4000 chars. Use bullets. First 2–3 lines are visible without "read more" on the store — lead with value.
- **`keywords.txt`**: comma-separated list, no spaces around commas. Apple ranks search by these + the app name. 100 chars total.
- **`promotional_text.txt`**: only appears on the listing if you've published. Can be updated without a new binary — use for temporary announcements.
- **`release_notes.txt`**: version-specific "What's New" text. Keep bullets. First release: something positive; later: bug fixes / features.
- **URL files**: must be live HTTPS at submit time. Apple crawls them during review; 404s = auto-reject.
- **`review_information/` files**: reviewer contact info. Use a real phone number — Apple occasionally calls for complex apps. `demo_*` only if the app has a login screen (most utilities don't).
- **`notes.txt`**: the most important one. Explain anything non-obvious: required permissions, IAP test steps, third-party integrations, privacy choices.

## Screenshots

### Dimensions Apple accepts (macOS)

Pick one set and stick with it across all screenshots in a locale:

- 1280×800 (16:10 standard)
- 1440×900 (16:10 larger)
- 2560×1600 (Retina of 1280×800)
- **2880×1800** (Retina of 1440×900) ← recommended default for modern displays

Apple won't mix ratios within a locale. All screenshots must be the same dimensions.

### Capture approach

Retina Macs natively screenshot at 2x logical:

```sh
# Full-screen, no cursor, PNG
screencapture -x -t png /tmp/shot.png

# Check dimensions
sips -g pixelWidth -g pixelHeight /tmp/shot.png
# -> pixelWidth: 2992, pixelHeight: 1934 (on a 1496x967 logical display)

# Resize to Apple's exact 2880×1800
sips -z 1800 2880 /tmp/shot.png --out fastlane/screenshots/en-US/01_main.png
```

(If your Mac is non-Retina or external low-DPI display, capture at 1x and aim for 1440×900 directly.)

### Composition tips

- **App should dominate** the frame. Desktop wallpaper as background is fine; avoid showing other app windows unless it's the product demo (e.g. the popover + target app).
- **Populate with real content** — empty states look unpolished. Use representative data.
- **Order matters** — Apple shows screenshots in filename sort order. Lead with the hero shot (main window in active use), then features, then settings last.
- **Consistency** — if screenshot #1 has the window at 1200×700 centered, screenshot #2 shouldn't be 800×500 off-center.

### Recommended shot list (4 shots)

1. **Main window in use** — populated, realistic content, primary interaction visible.
2. **Key differentiator feature** — the thing this app does that alternatives don't.
3. **Settings or configuration** — shows depth, reassures power users.
4. **Optional: IAP value** — only if you have one, show the paid feature working (not the paywall).

### IAP review screenshot (separate)

Apple requires a screenshot specifically for the IAP product's review record. This goes in App Store Connect's IAP edit page (not in `fastlane/screenshots/`). It should show:

- The paid feature in context
- The unlock CTA if relevant

640×920 is the minimum; higher is fine. Reuse a screenshot that shows the settings panel with the unlock button.

Save to `fastlane/metadata/review_information/iap_review_screenshot.png` for bookkeeping — you'll upload it manually in Phase 7.

## Localization

To support more than `en-US`, clone the `en-US/` directory to `<locale>/` (e.g. `fr-FR/`, `de-DE/`, `ja/`) and translate each `.txt`. Screenshots can be localized the same way under `fastlane/screenshots/<locale>/`. Apple's App Store shows the appropriate locale's content based on the user's store region.

For a v1.0 launch, `en-US` only is standard. Add locales later based on install data.

## Pre-upload check

```sh
bundle exec fastlane run precheck \
  app_identifier:{{BUNDLE_ID}} \
  api_key_path:<path/to/api_key.json>
```

Precheck catches common reasons Apple rejects (prohibited content, placeholder text, broken URLs) before you submit. Not perfect but cheap to run.
