# Community submission draft

Title: `[Plugin]: AI Model Usage`

Target: https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml

Fields below follow the marketplace's `submit-plugin.yml` form. The source is
public at commit `997c74e` (source-only, no bundled binaries). No marketplace
issue has been created; the two unticked checklist items need the owner's
confirmation before submitting.

---

### Repository URL

https://github.com/sabrodigan/omarchy-ai-usage

### Category

Developer Tools

### Tags

AI, Bar, Quickshell

### Suggest a missing tag

_No response_

### Maintainer notes

Bar widget for Omarchy Quattro showing this month's local AI coding-agent usage
(tokens, responses, estimated cost) with a themed popup and a tmux dashboard.

Dependencies: Python 3 (standard library only), tmux, and a separately installed
[Tokscale](https://github.com/junhoyeo/tokscale) (tested with 4.15.0). Optional:
the [`usage`](https://github.com/sabrodigan/ai-usage-command) CLI 2.2.0+, which
adds agents Tokscale cannot read — Meta Muse (tokens and cost from its session
journals) and Cursor (prompts per model, e.g. grok-4.6). Without it those rows
are omitted.

Source-only release: no bundled binaries, credentials, personal records, or usage
databases. No install hooks, privileged operations, account login, usage
submission, or automatic downloads. The collector reads only the current user's
local session records and returns aggregate counts; `usage` is invoked with
`--no-config`, so its config and key vault are never read. Tokscale may refresh
public pricing metadata.

Counts cover the current calendar month; costs are estimates and quotas are
unavailable. Agents with no recorded usage are omitted automatically.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [ ] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [ ] I understand that approval is for listing and is not a security review.
