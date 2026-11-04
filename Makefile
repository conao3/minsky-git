.PHONY: check lint format-check test

check: format-check lint test

format-check:
	shfmt -d bin/git-minsky tests/run.sh
	nixfmt --check flake.nix

lint:
	shellcheck bin/git-minsky tests/run.sh

test:
	tests/run.sh
