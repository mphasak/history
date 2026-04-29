#!/usr/bin/env bash
# Harness umbrella runner. See harness/README.md for what each subcommand
# checks and why. Exits non-zero on any failure (except `drift`, which is
# advisory and prints a report).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cmd="${1:-check}"

case "$cmd" in
  check)     bash "$HERE/health.sh"     && \
             bash "$HERE/tests.sh"      && \
             bash "$HERE/golden.sh"     && \
             bash "$HERE/invariants.sh" ;;
  health)    bash "$HERE/health.sh" ;;
  tests)     bash "$HERE/tests.sh" ;;
  golden)    bash "$HERE/golden.sh" ;;
  drift)     bash "$HERE/drift.sh" ;;
  invariants) bash "$HERE/invariants.sh" ;;
  *)
    echo "usage: $0 {check|health|tests|golden|drift|invariants}" >&2
    exit 2
    ;;
esac
