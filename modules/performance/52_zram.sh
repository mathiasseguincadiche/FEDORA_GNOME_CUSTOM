#!/usr/bin/env bash
set -Eeuo pipefail

# swap-on-zram Fedora par défaut préservé : observabilité seule, jamais de taille, d'algorithme de compression ni de swappiness imposé.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
source "$REPO_ROOT/lib/performance_runtime.sh"

performance_zram_precheck() { [[ "$(performance_policy_get zram_policy)" == fedora-default ]]; }
performance_zram_plan() { echo 'Preserve Fedora swap-on-zram defaults; add observability only and never impose a custom size, compression algorithm or global swappiness value.'; }
performance_zram_apply() {
  is_true "${DRY_RUN:-true}" && return 0
  run_mutating PERFORMANCE sudo systemctl daemon-reload || return "$EXIT_APPLY_FAILED"
}
performance_zram_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/zram-doctor" --quiet
}
