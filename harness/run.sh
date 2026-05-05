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
  gaps)
    shift
    # Prefer the project venv if present (psycopg lives there); else system python3.
    if [[ -x "$ROOT/.venv/bin/python" ]]; then
      "$ROOT/.venv/bin/python" "$HERE/audit_gaps.py" "$@"
    else
      python3 "$HERE/audit_gaps.py" "$@"
    fi
    ;;
  *)
    echo "usage: $0 {check|health|tests|golden|drift|invariants|gaps}" >&2
    exit 2
    ;;
esac
