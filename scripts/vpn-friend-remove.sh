#!/usr/bin/env bash
# Отозвать доступ у друга: удаляет его клиента и shortId из конфига xray.
# Остальных друзей не трогает. Запуск НА СЕРВЕРЕ AEZA:
#   sudo scripts/vpn-friend-remove.sh <имя> [--no-reload]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

NAME="${1:-}"; RELOAD=1
[ "${2:-}" = "--no-reload" ] && RELOAD=0
[ -n "$NAME" ] || die "укажите имя: vpn-friend-remove.sh <имя>"

require_cmd jq
require_root
ensure_secrets_store

LINE="$(grep -iP "^${NAME}\t" "$FRIENDS_SECRETS" 2>/dev/null || true)"
[ -n "$LINE" ] || die "друг '$NAME' не найден в реестре"
UUID="$(printf '%s' "$LINE" | cut -f2)"
SHORTID="$(printf '%s' "$LINE" | cut -f3)"

[ -f "$XRAY_CONFIG" ] || die "конфиг xray не найден: $XRAY_CONFIG"
BAK="$(backup_file "$XRAY_CONFIG")"
IDX="$(xray_reality_inbound_index "$XRAY_CONFIG")"
[ -n "$IDX" ] || die "REALITY-inbound не найден в $XRAY_CONFIG"

TMP="$(mktemp)"
jq \
  --argjson i "$IDX" --arg id "$UUID" --arg sid "$SHORTID" '
  .inbounds[$i].settings.clients |= map(select(.id != $id))
  | .inbounds[$i].streamSettings.realitySettings.shortIds |= map(select(. != $sid))
  ' "$XRAY_CONFIG" > "$TMP"
mv "$TMP" "$XRAY_CONFIG"
xray_validate_or_rollback "$XRAY_CONFIG" "$BAK"
ok "клиент '$NAME' удалён из xray"

# Чистим реестры
grep -viP "^${NAME}\t" "$FRIENDS_SECRETS" > "${FRIENDS_SECRETS}.tmp" || true
mv "${FRIENDS_SECRETS}.tmp" "$FRIENDS_SECRETS"; chmod 600 "$FRIENDS_SECRETS"
# в friends.yaml помечаем статус revoked (не удаляем — для истории)
if command -v python3 >/dev/null 2>&1; then
  python3 - "$FRIENDS_REGISTRY" "$NAME" <<'PY' || warn "не смог обновить friends.yaml, поправьте вручную"
import sys,re
path,name=sys.argv[1],sys.argv[2]
s=open(path).read().splitlines()
out=[]; i=0
while i<len(s):
    out.append(s[i])
    if s[i].strip()==f"- name: {name}" or s[i].strip()==f"name: {name}":
        # пометить следующий блок status: revoked
        j=i+1
        while j<len(s) and s[j].startswith("    "):
            if "status:" in s[j]:
                s[j]=re.sub(r"status:.*","status: revoked",s[j])
            out.append(s[j]); j+=1
        i=j; continue
    i+=1
open(path,"w").write("\n".join(out)+"\n")
PY
fi

if [ "$RELOAD" -eq 1 ]; then
  log "перезапуск сервиса $XRAY_SERVICE"
  systemctl restart "$XRAY_SERVICE" && ok "$XRAY_SERVICE перезапущен" || warn "перезапустите вручную"
else
  warn "перезапуск пропущен (--no-reload)."
fi
ok "Доступ у '$NAME' отозван. Его ссылка больше не работает; остальные не затронуты."
warn "Закоммитьте обновлённый state/friends.yaml в git."
