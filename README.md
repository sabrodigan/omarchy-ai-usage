# AI Model Usage — Omarchy bar plugin

Monthly AI agent usage from local session records. The bar shows token totals;
click for each active agent, response counts, last activity, and estimated costs.
Refreshes every 60 seconds and every 10 seconds while the popup is open.

Claude CLI uses its session logs, not an Anthropic API key. Codex and Antigravity
CLI also use local records. Agents without records in the current calendar month
are hidden, and appear automatically once readable usage is recorded.
Installing or signing into a tool alone does not count as usage.

## Requirements

- Omarchy Quattro with Quickshell plugins.
- Python 3 (standard library only).
- tmux, for a persistent dashboard footer.
- [Tokscale](https://github.com/junhoyeo/tokscale), tested with 4.15.0.
  Install it separately using its upstream installation instructions. The plugin
  finds `tokscale` on PATH or at `~/.local/bin/tokscale`; `TOKSCALE_BIN` can select
  an explicit executable path. Nothing is downloaded or installed by this plugin.
- Optional: the [`usage`](https://github.com/sabrodigan/ai-usage-command) CLI (2.2.0+, with
  `usage local`). When found on PATH or at `~/.local/bin/usage` (`USAGE_BIN` overrides),
  it adds agents Tokscale cannot read: **Meta Muse** (token counts and cost from
  Muse's session journals and model catalog) and **Cursor** (prompts per model, e.g.
  `grok-4.6`, from Cursor's local chat history). Without it those rows are omitted.

## Install and remove

```bash
omarchy plugin add https://github.com/sabrodigan/omarchy-ai-usage.git --enable
omarchy bar move sabrodigan.ai-usage --section right
```

Update or remove:

```bash
omarchy plugin update sabrodigan.ai-usage
omarchy plugin remove sabrodigan.ai-usage
```

Removal removes the plugin. Agent session logs and the separately installed
Tokscale application remain in their own locations.

## Settings

Use the widget settings panel, or its entry in `~/.config/omarchy/shell.json`:

- `badgeMetric`: `Total tokens` (default), `Total cost`, or `Both`.
- `refreshIntervalSec`: local scan interval, default 60 seconds.
- `timeoutSec`: scan timeout, default 30 seconds, maximum 120.
- `warnPercent`: retained for compatibility; local records do not expose quotas,
  so local totals do not trigger quota warnings.

Older `Top usage %` settings fall back to token totals when no quota is known.

## What the numbers mean

Counters come from `tokscale graph --month`, grouped by client. Tokens include
input, output, cache reads, cache writes, and reasoning as reported by Tokscale.
The period is the current calendar month, not a provider billing cycle. Counters
reset at the start of each month. Responses are the collector's message count.

These are local recorded totals, not account-wide subscription limits. Cloud
sessions or clients without readable exports may be absent. Cursor, Warp, and
some other clients require caches/integrations described in Tokscale's docs.
Use `tokscale clients` to inspect available sources. When the optional `usage`
CLI is installed, Muse and Cursor rows come from `usage local --no-config`; Tokscale
wins if both report the same agent. Cursor keeps token counts server-side, so its
row shows prompts sent per model rather than tokens, with no cost. No file-size estimates,
invented quotas, or API authentication checks are used.

Costs prefixed with `~` are Tokscale estimates, not invoices or subscription
charges. Unknown prices can contribute zero to the estimate. The `local` label
means records were read; it does not assert that credentials are valid.
A failed refresh shows an error instead of presenting the previous total as fresh.
The displayed refresh time is the scan time; last activity is the latest record date.

## Privacy and permissions

The plugin ships source code only, with no credentials, histories, databases,
usage snapshots, account identifiers, or personal machine paths. It does not
read `~/.config/ai-usage` or scan for keys (`usage local --no-config` reads only
agent session records). QML runs the Python helper, which runs
Tokscale to read the current user's local agent records and returns aggregate
counts only. Results are held in widget memory, not saved by the plugin.

Tokscale may read/write its own caches and fetch public model pricing metadata.
The plugin never invokes login, submit, autosubmit, credential extraction, or
remote account integration commands. It does not upload usage or enable syncing.
The dashboard button opens `tokscale --refresh 60 tui --month` in a private
tmux session in your terminal. Its footer reads the AI Usage version and author
from `manifest.json`, alongside a Tokscale credit. Existing tmux sessions and
configuration are unaffected; the private session exits when you quit with `q`.

## Validate

```bash
omarchy plugin validate .
python3 -m unittest discover -s tests -v
bin/usage-run now --json --timeout 30
```

`bin/usage-run` intentionally uses the local collector rather than an unrelated
`usage` executable on PATH. This prevents older installed binaries from silently
restoring API-key checks or inaccurate estimates.

## License

AGPL-3.0-or-later. See [LICENSE](LICENSE). Tokscale is a separately installed
third-party dependency, governed by its own license.
