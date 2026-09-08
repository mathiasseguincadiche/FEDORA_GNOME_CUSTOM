#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

# Kernel lifecycle commands are routed directly to the dedicated engine so the
# operator CLI can expose candidate -> certify without duplicating business logic.
if [[ "${1:-}" == kernel ]]; then
  case "${2:-}" in
    candidate|boot-candidate|certify|rollback)
      exec bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" "$2"
      ;;
    rollback-fedora)
      exec bash "$REPO_ROOT/scripts/kernel/rollback-to-fedora.sh"
      ;;
  esac
fi

# Offline update continuation is exposed at the top-level facade because the
# base control-center menu historically only prepared transactions. Keep the
# actual update state machine in update-system.sh.
if [[ "${1:-}" == update ]]; then
  case "${2:-}" in
    reboot)
      exec bash "$REPO_ROOT/scripts/maintenance/update-system.sh" --offline-reboot
      ;;
    finalize)
      exec bash "$REPO_ROOT/scripts/maintenance/update-system.sh" --finalize
      ;;
    status)
      exec bash "$REPO_ROOT/scripts/maintenance/update-system.sh" --offline-status
      ;;
    log)
      exec bash "$REPO_ROOT/scripts/maintenance/update-system.sh" --offline-log
      ;;
  esac
fi

# Evidence retention is deliberately explicit. A plain prune is a dry-run;
# destructive cleanup requires the unambiguous prune-apply action.
if [[ "${1:-}" == logs ]]; then
  case "${2:-}" in
    prune)
      exec bash "$REPO_ROOT/scripts/maintenance/prune-project-evidence.sh" --dry-run
      ;;
    prune-apply)
      exec bash "$REPO_ROOT/scripts/maintenance/prune-project-evidence.sh" --apply
      ;;
  esac
fi

# Three-gate validation is intentionally routed to dedicated engines. Gate 1
# and Gate 2 can never invoke production APPLY/final certification; Gate 3 is
# the only path that delegates to the bare-metal final-certification engine.
if [[ "${1:-}" == validate ]]; then
  case "${2:-status}" in
    status)
      exec bash "$REPO_ROOT/scripts/validation/status.sh"
      ;;
    import)
      [[ -n "${3:-}" ]] || { echo 'Usage: ./control.sh validate import PROOF.json' >&2; exit "$EXIT_USAGE"; }
      exec bash "$REPO_ROOT/scripts/validation/import-proof.sh" "$3"
      ;;
    export)
      [[ -n "${3:-}" && -n "${4:-}" ]] || { echo 'Usage: ./control.sh validate export GATE DESTINATION_DIR' >&2; exit "$EXIT_USAGE"; }
      exec bash "$REPO_ROOT/scripts/validation/export-proof.sh" "$3" "$4"
      ;;
    gate1)
      exec bash "$REPO_ROOT/scripts/validation/gate1-wsl2.sh" "${3:-run}"
      ;;
    gate2)
      exec bash "$REPO_ROOT/scripts/validation/gate2-virtualbox.sh" "${3:-status}"
      ;;
    gate3)
      exec bash "$REPO_ROOT/scripts/validation/gate3-baremetal.sh" "${3:-status}"
      ;;
    help|-h|--help)
      cat <<'EOF'
Three-gate validation commands:
  ./control.sh validate status
  ./control.sh validate gate1 [run|status]
  ./control.sh validate import PROOF.json
  ./control.sh validate gate2 [plan|apply|check|sign|status]
  ./control.sh validate export GATE DESTINATION_DIR
  ./control.sh validate gate3 [status|record-suspend|certify]
EOF
      exit 0
      ;;
    *)
      echo 'Unknown validation command. Use: ./control.sh validate help' >&2
      exit "$EXIT_USAGE"
      ;;
  esac
fi

# shellcheck source=lib/control_center.sh
source "$REPO_ROOT/lib/control_center.sh"
# shellcheck source=lib/control_center_operator_polish.sh
[[ ! -r "$REPO_ROOT/lib/control_center_operator_polish.sh" ]] || source "$REPO_ROOT/lib/control_center_operator_polish.sh"
control_center_main "$@"
