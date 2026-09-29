# Community submission draft

Title: `[Plugin]: AI Model Usage`

Target: https://github.com/omacom/omarchy-plugin-marketplace/issues/new

Publish the prepared source changes to the public repository before submitting.
The following is a draft; ownership and publication checklist items remain for
owner review. No marketplace issue has been created.

---

### Repository URL

https://github.com/sabrodigan/omarchy-ai-usage

### Category

Developer Tools

### Tags

ai, bar, quickshell

### Suggest a missing tag

_No response_

### Maintainer notes

Local agent usage widget for Omarchy Quattro. Python 3, tmux, and a separately installed
Tokscale are required (tested with 4.15.0). Source-only release; no bundled
binaries, credentials, personal records, or usage databases. No install hooks,
privileged operations, account login, usage submission, or automatic downloads.
Tokscale reads local session records and may refresh public pricing metadata.
Counts cover the current calendar month; costs are estimates and quotas are
unavailable. Agents with no recorded usage are omitted automatically.

### Submission checklist

- [ ] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [ ] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [ ] I understand that approval is for listing and is not a security review.
