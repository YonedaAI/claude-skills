# claude-skills

A small marketplace of [Claude Code](https://docs.claude.com/en/docs/claude-code) plugins, built by YonedaAI. Each plugin captures a real production workflow — research papers, Mac App Store releases — distilled into an installable skill.

**Browse the site:** <https://yonedaai.github.io/claude-skills/>

## Plugins

| Plugin | Version | Description |
|--------|---------|-------------|
| [`research-agent`](./research-agent-skill/) | `0.7.9` | Multi-agent research pipeline with Gemini peer review, Codex formatting, optional Haskell verification, Vercel deployment, social posts, and Slack notifications. |
| [`app-store-publish`](./app-store-publish/) | `0.1.0` | End-to-end Mac App Store publishing pipeline for SwiftUI apps: fastlane setup, certs/profiles, sandboxed builds, StoreKit 2 IAP, screenshots, metadata, submission. |

## Install the marketplace

From inside Claude Code:

```
/plugin marketplace add YonedaAI/claude-skills
```

Then install any plugin:

```
/plugin install research-agent@local-skills
/plugin install app-store-publish@local-skills
```

## License

MIT — YonedaAI Research Collective
