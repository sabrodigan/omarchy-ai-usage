PLUGIN_ID = sabrodigan.ai-usage
USAGE_BIN ?= $(shell command -v usage)

.PHONY: test contract check install

# Unit tests; the end-to-end contract test is skipped without USAGE_BIN.
test:
	python3 -m unittest discover -s tests

# End-to-end test against a real `usage` binary (default: the one on PATH).
contract:
	@test -n "$(USAGE_BIN)" || { echo "usage not found; set USAGE_BIN"; exit 1; }
	USAGE_BIN=$(USAGE_BIN) python3 -m unittest tests.test_usage.UsageLocalContractTest -v

check: test contract
	omarchy plugin validate "$(CURDIR)"

# Pull the pushed version into the installed Omarchy plugin.
install:
	omarchy plugin update $(PLUGIN_ID) --yes
