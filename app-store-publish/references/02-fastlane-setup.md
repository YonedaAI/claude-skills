# Phase 2 — Fastlane setup

Install fastlane locally (no sudo), configure secrets cleanly (not in source control), and set up the `asc_api_key` helper that every lane uses.

## Gemfile

At repo root:

```ruby
source "https://rubygems.org"

gem "fastlane"
gem "dotenv"
```

## bundle install (no sudo)

System Ruby requires sudo to write to `/Library/Ruby/Gems`. Avoid this — install locally:

```sh
bundle config set --local path 'vendor/bundle'
bundle install --path vendor/bundle
```

(On Bundler 1.x the flag works; on 2.x the config is preferred. Both forms land in the same place.)

Verify:

```sh
bundle exec fastlane --version
# -> fastlane 2.231.x (and Ruby-version warning for 2.6.10 — ignore for now)
```

## `.keys/` directory

Consolidated location for cryptographic material. At repo root:

```
.keys/
  AuthKey_<KEY_ID>.p8                          # App Store Connect API key
  {{APP_STORE_PROVISIONING_PROFILE_NAME}}.provisionprofile   # populated by mas_setup in Phase 3
```

Never commit this directory. Verify `.gitignore` excludes it.

## `.env` file

Fastlane's `Fastfile` loads `.env` via the `dotenv` gem. Content:

```
APP_STORE_CONNECT_API_KEY_ID=<10-char key ID>
APP_STORE_CONNECT_API_ISSUER_ID=<UUID>
APP_STORE_CONNECT_API_KEY_PATH=.keys/AuthKey_<KEY_ID>.p8
```

Also check in a `.env.example` with the same keys but placeholder values — makes onboarding for collaborators/CI obvious.

## .gitignore additions

```
.keys/
.env
.env.local
.env.*.local
*.p8
vendor/bundle/
.bundle/
fastlane/api_key.json
fastlane/report.xml
fastlane/README.md
fastlane/test_output
fastlane/screenshots/**/*.png
fastlane/screenshots/**/*.jpg
```

The fastlane-specific ignores keep local caches and regenerated files out of commits.

## Fastfile helper

The `asc_api_key` helper at the top of `Fastfile` resolves the `.env` values into a fastlane `api_key` object. Critical: use `key_filepath` (references the `.p8` on disk), **not** `key_content` (inlines the private key bytes into the Ruby process — and potentially into shell history / ps output).

```ruby
require "dotenv"
Dotenv.load(File.expand_path("../.env", __dir__))

def asc_api_key
  key_id = ENV["APP_STORE_CONNECT_API_KEY_ID"]
  issuer_id = ENV["APP_STORE_CONNECT_API_ISSUER_ID"]
  key_path = ENV["APP_STORE_CONNECT_API_KEY_PATH"]
  return nil if key_id.nil? || issuer_id.nil? || key_path.nil?
  absolute_key_path = File.expand_path(key_path, File.expand_path("..", __dir__))
  return nil unless File.exist?(absolute_key_path)
  app_store_connect_api_key(
    key_id: key_id,
    issuer_id: issuer_id,
    key_filepath: absolute_key_path,
    in_house: false
  )
end
```

Every downstream lane calls `asc_api_key` and passes the result via `api_key:` to the actual action (`get_certificates`, `get_provisioning_profile`, `upload_to_app_store`, `upload_to_testflight`, `notarize`).

## Appfile

`fastlane/Appfile` — small, just team + bundle identity. Example:

```ruby
app_identifier "{{BUNDLE_ID}}"
team_id "{{TEAM_ID}}"
```

Used by actions that default team/app from here.

## Deliverfile

`fastlane/Deliverfile` — points deliver at metadata + screenshots.

```ruby
app_identifier "{{BUNDLE_ID}}"
team_id "{{TEAM_ID}}"
platform "osx"
skip_binary_upload true
metadata_path "./fastlane/metadata"
screenshots_path "./fastlane/screenshots"
```

`skip_binary_upload true` is set here because the `mas_release` lane handles binary upload explicitly — keeps concerns cleanly split.

## Smoke test

Confirm the fastlane + env wiring works without committing anything real:

```sh
bundle exec fastlane run app_store_connect_api_key \
  key_id:$APP_STORE_CONNECT_API_KEY_ID \
  issuer_id:$APP_STORE_CONNECT_API_ISSUER_ID \
  key_filepath:$PWD/$APP_STORE_CONNECT_API_KEY_PATH
```

Successful output ends with "fastlane.tools finished successfully". If it prompts for 2FA, your key isn't being read — check `.env` format (no spaces around `=`).
