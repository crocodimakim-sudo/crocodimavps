#!/usr/bin/env bash
# Список друзей. По умолчанию — без секретов (имя, статус).
# С флагом --links печатает персональные ссылки (только на сервере, где есть .secrets).
#   scripts/vpn-friend-list.sh            # безопасный список
#   scripts/vpn-friend-list.sh --links    # + ссылки (осторожно: секреты!)
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

SHOW_LINKS=0
[ "${1:-}" = "--links" ] && SHOW_LINKS=1

if [ "$SHOW_LINKS" -eq 0 ]; then
  if [ -f "$FRIENDS_REGISTRY" ]; then
    log "Реестр друзей (state/friends.yaml):"
    grep -E '^\s+- name:|^\s+status:|^\s+added:' "$FRIENDS_REGISTRY" 2>/dev/null || echo "  (пусто)"
  else
    echo "(реестр не найден)"
  fi
  exit 0
fi

# --links: читаем из секретного файла
[ -f "$FRIENDS_SECRETS" ] || die "нет $FRIENDS_SECRETS (секреты есть только на сервере)"
warn "Ниже персональные ссылки — это секреты доступа. Не публикуйте."
while IFS=$'\t' read -r NAME UUID SHORTID; do
  [ -n "$NAME" ] || continue
  echo "----------------------------------------"
  echo "friend: $NAME"
  echo "vless://${UUID}@${VPN_HOST}:${VPN_PORT}?security=reality&flow=${VPN_FLOW}&sni=${VPN_SNI}&fp=${VPN_FP}&pbk=${VPN_PBK}&sid=${SHORTID}&type=tcp&headerType=none#HELs-${NAME}"
done < "$FRIENDS_SECRETS"
