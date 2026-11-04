#!/usr/bin/env bash
# Run every example machine with "git fetch loop" and compare the final state.
set -euo pipefail
cd "$(dirname "$0")/.."
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0
n=0

expect() {
	local prog=$1 a=$2 b=$3 want=$4
	n=$((n + 1))
	local repo=$work/$n
	bin/git-minsky machine create-repository --repository-path "$repo" \
		--program "file://examples/$prog.prog" --counter-a "$a" --counter-b "$b" >/dev/null
	git -C "$repo" fetch loop >/dev/null 2>&1 || true
	local got
	got=$(bin/git-minsky --output text machine describe-state --repository-path "$repo")
	if [[ $got == "$want" ]]; then
		echo "ok   $prog a=$a b=$b -> $got"
	else
		echo "FAIL $prog a=$a b=$b -> $got (want $want)"
		failed=1
	fi
}

expect double 0 0 $'H\t0\t0\ttrue'
expect double 6 0 $'H\t0\t12\ttrue'
expect double 40 0 $'H\t0\t80\ttrue'
expect add 3 4 $'H\t7\t0\ttrue'
expect halve 6 0 $'E\t0\t3\ttrue'
expect halve 7 0 $'O\t0\t3\ttrue'

if bin/git-minsky machine create-repository --repository-path "$work/bad" \
	--program '1 jump 2' >/dev/null 2>&1; then
	echo "FAIL a bad instruction was accepted"
	failed=1
else
	echo "ok   a bad instruction is rejected"
fi

exit "$failed"
