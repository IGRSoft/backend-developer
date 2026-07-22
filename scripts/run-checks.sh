#!/usr/bin/env bash
#
# run-checks.sh — repo lint aggregator (runs from any cwd via BASH_SOURCE).
#
# This repo has no test.sh / CI harness, so this is the single entry point that
# ties the manifest validator and the prose linters together. Every check runs
# to completion so one FATAL failure never masks the state of the others; the
# verdict and exit code reflect only the fatal checks. section-lint is advisory.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

status=OK
which=""
note_fail() { status=FAIL; if [ -z "${which}" ]; then which="$1"; else which="${which},$1"; fi; }

# (a) manifest validator — FATAL. Run WITHOUT --strict: it has known WARN-level
#     findings and exits 0 on warnings, so a nonzero exit is a real ERROR.
echo "== validate =="
if scripts/validate.sh; then :; else note_fail validate; fi

# (b) description-length lint — FATAL. Self-test guards the parser, then real run.
echo "== desc-lint =="
if scripts/desc-lint.sh --self-test && scripts/desc-lint.sh; then :; else note_fail desc-lint; fi

# (c) section-length lint — WARN-ONLY: pre-existing prose-debt baseline. Never
#     fails the aggregate; surface the count so the burn-down stays visible.
echo "== section-lint (warn-only) =="
scripts/section-lint.sh --self-test || echo "run-checks: WARN section-lint self-test failed (parser regression?)"
sec_summary="$(scripts/section-lint.sh 2>/dev/null | tail -n1 || true)"
printf 'run-checks: WARN section-lint (warn-only): %s\n' "${sec_summary:-no summary}"

echo
if [ "${status}" = OK ]; then
	echo "run-checks: OK"
else
	echo "run-checks: FAIL (${which})"
	exit 1
fi
