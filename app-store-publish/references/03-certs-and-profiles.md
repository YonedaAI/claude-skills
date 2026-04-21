# Phase 3 — Certs + provisioning profile via API

`mas_setup` is an idempotent lane. It fetches or creates the three artifacts required for MAS signing:

1. **Apple Distribution** cert — signs the `.app`.
2. **3rd Party Mac Developer Installer** cert — signs the `.pkg` that wraps the `.app`.
3. **Mac App Store** provisioning profile — binds the cert to `{{BUNDLE_ID}}`, includes any capabilities (CloudKit, app groups, etc.).

## The lane

See `templates/Fastfile.template` for the full `mas_setup`. Core structure:

```ruby
lane :mas_setup do
  key = asc_api_key
  UI.user_error!("Missing App Store Connect API key") unless key

  UI.header("Fetching/creating Apple Distribution cert")
  get_certificates(
    api_key: key,
    platform: "macos",
    generate_apple_certs: true,
    output_path: "./.keys"
  )
  app_cert_id = lane_context[SharedValues::CERT_CERTIFICATE_ID]

  UI.header("Fetching/creating Mac Installer Distribution cert")
  get_certificates(
    api_key: key,
    platform: "macos",
    type: "mac_installer_distribution",
    output_path: "./.keys"
  )

  UI.header("Fetching/creating Mac App Store provisioning profile")
  get_provisioning_profile(
    api_key: key,
    platform: "macos",
    app_identifier: "{{BUNDLE_ID}}",
    provisioning_name: "{{APP_STORE_PROVISIONING_PROFILE_NAME}}",
    cert_id: app_cert_id,
    output_path: "./.keys"
  )
end
```

## Gotchas (in order of encounter)

### 1. Admin role

```
You do not have permission to create this certificate.
Only Team Admins can create Distribution certificates.
```

The API key lacks Admin role. Regenerate the key with Admin role (or create a second, Admin-scoped key just for cert creation; demote/delete after).

### 2. `app_store: true` isn't a macOS option

```
Could not find option 'app_store' in the list of available options:
adhoc, developer_id, development, skip_install, force, ...
```

On macOS, `get_provisioning_profile` defaults to App Store when no other type flag is passed. Remove `app_store: true`. (On iOS it's valid; fastlane's shared codebase misleads here.)

### 3. Profile filename validator

```
The output name must end with .mobileprovision
```

Drop the custom `filename:` arg — let fastlane name it. The file ends up at `.keys/AppStore_{{BUNDLE_ID}}.provisionprofile` regardless of what sigh prints.

### 4. Cert type mismatch

```
Could not find a matching code signing identity for type 'AppStore'.
```

`get_provisioning_profile` looks for the legacy "3rd Party Mac Developer Application" cert by default, but with `generate_apple_certs: true` you got the modern "Apple Distribution". Fix: capture the cert ID from the first `get_certificates` call and pass it explicitly:

```ruby
app_cert_id = lane_context[SharedValues::CERT_CERTIFICATE_ID]
# ... then:
get_provisioning_profile(
  # ...
  cert_id: app_cert_id
)
```

Without `cert_id:`, sigh picks the wrong identity.

## After success

Keychain now contains two new identities:
```
Apple Distribution: {{TEAM_NAME}} ({{TEAM_ID}})
3rd Party Mac Developer Installer: {{TEAM_NAME}} ({{TEAM_ID}})
```

Profile is installed to `~/Library/MobileDevice/Provisioning Profiles/` and copied to `.keys/`. Apple Developer portal shows one new Mac App Store profile.

## Rerun safety

The lane is idempotent. Second run:
- `get_certificates` sees existing cert in Keychain, reuses it.
- `get_provisioning_profile` sees existing profile, updates if entitlements changed, re-downloads.

If you've rotated the key or want a fresh cert, revoke in Apple Developer portal first, then rerun.

## Cleanup

After successful setup, you can demote the Admin API key to a narrower role (App Manager) for day-to-day use — uploads and submissions don't require Admin. Rotate the `.env` to the narrower key's ID/issuer.
