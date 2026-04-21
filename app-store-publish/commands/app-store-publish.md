---
description: Walk through Mac App Store publishing for the current macOS SwiftUI app — fastlane setup, cert provisioning, sandboxed build, optional IAP, metadata, screenshots, review submission.
---

# /app-store-publish

You have received a request to publish a macOS app to the Mac App Store.

Invoke the `app-store-publish` skill and walk through the 7 phases. Before starting, check:

1. Is this a SwiftUI macOS app? (`find . -name "*.swift" -path "*/CopiedMac/*" -o -name "*App.swift"`)
2. Does it already have a Developer ID pipeline? (`ls scripts/build-release.sh` or similar)
3. Is there existing fastlane setup? (`ls fastlane/Fastfile Gemfile`)

Ask the user for any of these they haven't decided:
- `{{APP_STORE_APP_NAME}}` (the display name on the store, may differ from current `CFBundleDisplayName`)
- Whether to include an IAP (and if so, what feature it gates + price tier)
- Whether to keep both a Developer ID direct-download build and a MAS build (recommended)

Then orchestrate phases 1–7 from the skill, using TodoWrite to track progress. Stop at each phase boundary to let the user verify visible results.

**Do not batch-execute all phases silently.** Many things can fail mid-pipeline (cert creation permission, sandbox behavior, build signing, metadata validation). Stop and report at each boundary.
