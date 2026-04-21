# Phase 4 — Sandbox entitlements + local testing

Mac App Store requires `com.apple.security.app-sandbox: true`. Direct-download (Developer ID) builds usually don't sandbox. Keep both entitlement files in parallel, switch via the fastlane lane's build setting.

## Two entitlements files

```
{{TARGET_DIR}}/
  {{APP_NAME}}.entitlements       # existing: Developer ID (sandbox: false)
  {{APP_NAME}}-MAS.entitlements   # new:      MAS (sandbox: true)
```

### `{{APP_NAME}}-MAS.entitlements`

Minimum shape for a sandboxed utility with CloudKit sync:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>{{TEAM_ID}}.{{APP_GROUP_ID}}</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>{{ICLOUD_CONTAINER}}</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

Add additional sandbox entitlements as needed:
- `com.apple.security.files.downloads.read-write` — write to Downloads
- `com.apple.security.device.audio-input` — mic access
- `com.apple.security.device.camera` — camera access
- `com.apple.security.personal-information.calendars` — Calendar access
- `com.apple.security.automation.apple-events` + `com.apple.security.temporary-exception.apple-events` — AppleScript
- `com.apple.security.scripting-targets` — scripting a specific app by bundle ID

## Wiring in `project.yml` (XcodeGen)

```yaml
targets:
  {{APP_NAME}}:
    type: application
    platform: macOS
    sources:
      - {{APP_NAME}}
    settings:
      base:
        CODE_SIGN_ENTITLEMENTS: {{APP_NAME}}/{{APP_NAME}}.entitlements  # Developer ID default
    entitlements:
      path: {{APP_NAME}}/{{APP_NAME}}.entitlements
      properties:
        com.apple.security.app-sandbox: false
        # ... rest of Developer ID entitlements
```

Then the MAS-specific entitlements file lives alongside but isn't registered in `project.yml` — the fastlane lane overrides via `CODE_SIGN_ENTITLEMENTS=...` xcargs at build time.

## Fastlane lane: mas_build

Direct xcodebuild invocation (gym has opinions that don't match our scheme state). See `templates/Fastfile.template`:

```ruby
lane :mas_build do
  repo = File.expand_path("..", __dir__)
  sh("mkdir -p '#{repo}/build/mas'")

  archive_path = "build/mas/{{APP_NAME}}.xcarchive"
  sh(%(cd '#{repo}' && xcodebuild \
    -project {{APP_NAME}}.xcodeproj \
    -scheme {{APP_NAME}} \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath '#{archive_path}' \
    DEVELOPMENT_TEAM={{TEAM_ID}} \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY='Apple Distribution' \
    PROVISIONING_PROFILE_SPECIFIER='{{APP_STORE_PROVISIONING_PROFILE_NAME}}' \
    CODE_SIGN_ENTITLEMENTS={{APP_NAME}}/{{APP_NAME}}-MAS.entitlements \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='MAS_BUILD' \
    -allowProvisioningUpdates \
    archive))

  # ExportOptions.plist for app-store export, then exportArchive...
end
```

Two key settings:
- `CODE_SIGN_ENTITLEMENTS=...-MAS.entitlements` — overrides the project.yml default.
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS='MAS_BUILD'` — activates `#if MAS_BUILD` blocks for IAP code.

## AMFI: MAS apps can't launch locally

After `mas_build` produces `build/mas/{{APP_NAME}}.pkg` you might try `installer -pkg` or opening the archived `.app` directly. Both fail:

```
The application cannot be opened for an unexpected reason,
error=Error Domain=RBSRequestErrorDomain Code=5 "Launch failed."
NSLocalizedFailureReason=Launch failed.,
NSUnderlyingError=...Launchd job spawn failed
```

This is **by design** — Apple's Mobile File Integrity (AMFI) blocks Mac App Store-provisioned apps from launching outside the App Store's install path. You can't test sandbox behavior locally from a MAS-signed artifact.

**Solution: `mas_debug_build`** — Apple Development signing + MAS entitlements = sandboxed app that launches.

```ruby
lane :mas_debug_build do
  repo = File.expand_path("..", __dir__)
  sh("mkdir -p '#{repo}/build/mas-debug'")
  archive_path = "build/mas-debug/{{APP_NAME}}.xcarchive"
  sh(%(cd '#{repo}' && xcodebuild \
    -project {{APP_NAME}}.xcodeproj \
    -scheme {{APP_NAME}} \
    -configuration Debug \
    -destination 'generic/platform=macOS' \
    -archivePath '#{archive_path}' \
    DEVELOPMENT_TEAM={{TEAM_ID}} \
    CODE_SIGN_STYLE=Automatic \
    CODE_SIGN_ENTITLEMENTS={{APP_NAME}}/{{APP_NAME}}-MAS.entitlements \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG MAS_BUILD' \
    -allowProvisioningUpdates \
    archive))
  app = "#{repo}/#{archive_path}/Products/Applications/{{APP_NAME}}.app"
  sh("rm -rf '#{repo}/build/mas-debug/{{APP_NAME}}.app' && cp -R '#{app}' '#{repo}/build/mas-debug/{{APP_NAME}}.app'")
end
```

Then:
```sh
bundle exec fastlane mac mas_debug_build
open build/mas-debug/{{APP_NAME}}.app
```

Verify all features work under sandbox:
- Menu bar icon renders
- Global hotkey fires (if using Carbon hotkeys — requires Accessibility permission on first run)
- Pasteboard access works (no entitlement needed for NSPasteboard read)
- CloudKit sync (if entitled) connects — look for network traffic and verify data syncs
- File URL reads work (needs `com.apple.security.files.user-selected.read-write`)
- AppleScript (if used) — needs automation entitlements

## Sandbox container location

Under sandbox, the app's UserDefaults/Application Support/Caches are in:
```
~/Library/Containers/{{BUNDLE_ID}}/Data/
  Library/Preferences/{{BUNDLE_ID}}.plist
  Library/Application Support/
  Library/Caches/
  Documents/
```

Useful for debugging — `defaults read` that plist file directly to inspect state.

## Gotchas

- **XcodeGen wipes your Info.plist on regen.** If you've been editing `Info.plist` directly, xcodegen rewrites it from the subset of keys declared in `project.yml`. Move all plist values (CFBundleDisplayName, CFBundleShortVersionString, CFBundleVersion, CFBundleURLTypes, ITSAppUsesNonExemptEncryption, etc.) into `project.yml` `info.properties`.
- **`.xcscheme` files aren't on disk by default.** Xcode materializes schemes on demand. If fastlane/gym defaults to the wrong scheme name (uses project name instead of target), either: generate and commit shared schemes, use direct `xcodebuild` (as shown above), or add a `schemes:` block in `project.yml`.
- **CloudKit under sandbox needs explicit container init.** SwiftData's `ModelConfiguration(cloudKitDatabase: .private("..."))` works the same under sandbox as not, as long as the entitlement matches the container identifier.
