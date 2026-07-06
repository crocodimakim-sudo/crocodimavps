#!/usr/bin/env bash
# Добавить друга: генерирует УНИКАЛЬНЫЙ UUID + shortId, добавляет клиента в
# конфиг xray (REALITY) на сервере AEZA и печатает персональную VLESS-ссылку.
# Запуск НА СЕРВЕРЕ AEZA:  sudo scripts/vpn-friend-add.sh <имя> [--no-reload]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

NAME="${1:-}"; RELOAD=1
[ "${2:-}" = "--no-reload" ] && RELOAD=0
[ -n "$NAME" ] || die "укажите имя: vpn-friend-add.sh <имя>"
valid_name "$NAME" || die "имя только [a-zA-Z0-9_-], до 32 символов"

require_cmd jq
require_root
ensure_secrets_store

# Уже есть?
if grep -qiP "^${NAME}\t" "$FRIENDS_SECRETS" 2>/dev/null; then
  die "друг '$NAME' уже существует (см. vpn-friend-list.sh)"
fi

[ -f "$XRAY_CONFIG" ] || die "конфиг xray не найден: $XRAY_CONFIG (задайте XRAY_CONFIG=...)"

# Генерация уникальных идентификаторов
UUID="$(gen_uuid)"
require_cmd openssl
SHORTID="$(openssl rand -hex 8)"   # уникальный short id для этого друга

log "Друг: $NAME"
log "UUID: $UUID"
log "shortId: $SHORTID"

BAK="$(backup_file "$XRAY_CONFIG")"
IDX="$(xray_reality_inbound_index "$XRAY_CONFIG")"
[ -n "$IDX" ] || { warn "REALITY-inbound не найден автоматически"; die "проверьте $XRAY_CONFIG вручную"; }

TMP="$(mktemp)"
jq \
  --argjson i "$IDX" \
  --arg id "$UUID" \
  --arg name "$NAME" \
  --arg flow "$VPN_FLOW" \
  --arg sid "$SHORTID" \
  '
  .inbounds[$i].settings.clients += [ { "id": $id, "flow": $flow, "email": $name } ]
  | .inbounds[$i].streamSettings.realitySettings.shortIds += [ $sid ]
  | .inbounds[$i].streamSettings.realitySettings.shortIds |= unique
  ' "$XRAY_CONFIG" > "$TMP"

mv "$TMP" "$XRAY_CONFIG"
xray_validate_or_rollback "$XRAY_CONFIG" "$BAK"
ok "клиент добавлен в конфиг xray"

# Записываем в секретный реестр и в git-реестр (без секретов)
printf '%s\t%s\t%s\n' "$NAME" "$UUID" "$SHORTID" >> "$FRIENDS_SECRETS"
TODAY="$(date +%Y-%m-%d)"
if grep -q '^friends: \[\]' "$FRIENDS_REGISTRY" 2>/dev/null; then
  # заменяем пустой список на первую запись
  sed -i 's/^friends: \[\]/friends:/' "$FRIENDS_REGISTRY"
fi
{
  printf '  - name: %s\n' "$NAME"
  printf '    added: %s\n' "$TODAY"
  printf '    status: active\n'
} >> "$FRIENDS_REGISTRY"

# Перезагрузка xray (только этот сервис)
if [ "$RELOAD" -eq 1 ]; then
  log "перезапуск сервиса $XRAY_SERVICE"
  systemctl restart "$XRAY_SERVICE" && ok "$XRAY_SERVICE перезапущен" || warn "не смог перезапустить $XRAY_SERVICE — сделайте вручную"
else
  warn "перезапуск пропущен (--no-reload). Примените: systemctl restart $XRAY_SERVICE"
fi

# Персональная VLESS-ссылка
LINK="vless://${UUID}@${VPN_HOST}:${VPN_PORT}?security=reality&flow=${VPN_FLOW}&sni=${VPN_SNI}&fp=${VPN_FP}&pbk=${VPN_PBK}&sid=${SHORTID}&type=tcp&headerType=none#HELs-${NAME}"

echo
ok "Готово. Персональная ссылка для '$NAME' (уникальная):"
echo "$LINK"
echo
warn "Не забудьте закоммитить обновлённый state/friends.yaml (без секретов) в git."
