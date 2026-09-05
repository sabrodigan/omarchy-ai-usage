# AI Model Usage — Omarchy bar plugin

Live multi-provider AI token, request and quota tracking in the [Omarchy](https://omarchy.org)
status bar. Wraps the [`usage`](https://github.com/sabrodigan/ai-usage) CLI in a
Quickshell bar widget with a popup breakdown.

- **Bar badge** — the top provider's quota use (`54%`), turns red past a
  configurable threshold. Can show total monthly cost instead, or both.
- **Popup** — every configured provider ranked by quota use, with a coloured
  progress bar, consumed / quota amounts, per-provider cost, and total monthly
  spend. A button drops into the full `usage watch` TUI in your terminal.
- **No providers yet?** The popup offers a one-click `usage scan new` to detect
  installed AI tools (Claude, Codex, Copilot, Gemini, Cursor, Warp, Ollama, …).

The `usage` binary is **bundled** as a CGO-free static build for `x86_64` and
`aarch64`, so the plugin works on a fresh Omarchy install with no extra steps.
If you already have `usage` on your `PATH`, that copy is used instead.

## Install

```bash
omarchy plugin add https://github.com/sabrodigan/omarchy-ai-usage.git --enable
```

Pick a bar section when prompted (default: right). To place or move it later:

```bash
omarchy plugin enable sabrodigan.ai-usage --section right
omarchy bar move sabrodigan.ai-usage --section center
```

Update / remove:

```bash
omarchy plugin update sabrodigan.ai-usage
omarchy plugin remove sabrodigan.ai-usage
```

## Settings

Configured per-widget in `~/.config/omarchy/shell.json` (or the widget's
settings panel):

| Key | Default | Meaning |
|---|---|---|
| `badgeMetric` | `Top usage %` | Bar badge content: `Top usage %`, `Total cost`, or `Both`. |
| `refreshIntervalSec` | `60` | How often live provider data is refreshed. |
| `warnPercent` | `80` | Badge and rows turn urgent past this share of quota. |
| `timeoutSec` | `8` | Per-refresh timeout handed to `usage`. |

## IPC

```bash
omarchy-shell ipc call sabrodigan.ai-usage toggle
omarchy-shell ipc call sabrodigan.ai-usage refresh
```

## Files

```
manifest.json      Omarchy plugin manifest (schemaVersion 1, kind: bar-widget)
Widget.qml         Bar badge, refresh timer, `usage now --json` runner
UsagePopup.qml     Themed popup: ranked providers, progress bars, dashboard jump
bin/usage-run      Resolver: system `usage` on PATH, else the bundled binary
bin/usage-linux-*  Bundled static `usage` builds (amd64, arm64)
```

## Rebuilding the bundled binary

From a checkout of the [`usage`](https://github.com/sabrodigan/ai-usage) source:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" \
  -o /path/to/omarchy-ai-usage/bin/usage-linux-amd64 ./cmd/usage
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags="-s -w" \
  -o /path/to/omarchy-ai-usage/bin/usage-linux-arm64 ./cmd/usage
```

## License

AGPL-3.0-or-later, matching the `usage` project. See [LICENSE](LICENSE).
