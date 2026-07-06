#!/usr/bin/env bash
# Перезапуск ТОЛЬКО одного сервиса — не трогая остальное.
#   sudo scripts/restart-service.sh <xray|sing-box|openclaw> [restart|reload|status]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

WHAT="${1:-}"; ACTION="${2:-restart}"
case "$WHAT" in
  xray)     SVC="$XRAY_SERVICE" ;;
  sing-box) SVC="$SINGBOX_SERVICE" ;;
  openclaw) SVC="$OPENCLAW_SERVICE" ;;
  *) die "укажите сервис: xray | sing-box | openclaw" ;;
esac
case "$ACTION" in restart|reload|status|start|stop) ;; *) die "действие: restart|reload|status|start|stop" ;; esac

if [ "$ACTION" != "status" ]; then require_root; fi

log "$ACTION -> $SVC"
if [ "$ACTION" = "status" ]; then
  systemctl status "$SVC" --no-pager || true
else
  systemctl "$ACTION" "$SVC"
  ok "$SVC: $ACTION выполнен"
  systemctl is-active "$SVC" >/dev/null 2>&1 && ok "$SVC активен" || warn "$SVC НЕ активен — проверьте: journalctl -u $SVC -n 50"
fi
