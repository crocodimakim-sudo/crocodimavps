#!/usr/bin/env bash
# Применить правила маршрутизации из state/routing.yaml к конфигу sing-box.
# Запуск НА СЕРВЕРЕ Alibaba (где sing-box):
#   sudo scripts/apply-routing.sh [--no-reload]
# По умолчанию бэкапит конфиг, валидирует (sing-box check) и перезапускает сервис.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

RELOAD=1
[ "${1:-}" = "--no-reload" ] && RELOAD=0
: "${PROXY_TAG:=HELs-VLESS}"   # tag VPN-outbound в конфиге sing-box
: "${DIRECT_TAG:=direct}"

require_cmd jq
require_cmd python3
require_root
[ -f "$SINGBOX_CONFIG" ] || die "конфиг sing-box не найден: $SINGBOX_CONFIG"
ROUTING="$STATE_DIR/routing.yaml"
[ -f "$ROUTING" ] || die "нет $ROUTING"

# routing.yaml -> JSON набор правил (через python, без внешних зависимостей кроме stdlib)
RULES_JSON="$(python3 - "$ROUTING" "$PROXY_TAG" "$DIRECT_TAG" <<'PY'
import sys, json
path, proxy_tag, direct_tag = sys.argv[1], sys.argv[2], sys.argv[3]

# минимальный парсер нужного нам подмножества YAML
def parse(path):
    data={"direct":{"domains":[],"ip_cidr":[]},"proxy":{"domains":[]},"final":"proxy"}
    section=None; sub=None
    for raw in open(path):
        line=raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"): continue
        indent=len(line)-len(line.lstrip())
        s=line.strip()
        if indent==0 and s.endswith(":"):
            section=s[:-1]; sub=None; continue
        if indent==0 and ":" in s:
            k,v=s.split(":",1);
            if k=="final": data["final"]=v.strip()
            continue
        if indent==2 and s.endswith(":"):
            sub=s[:-1]; continue
        if s.startswith("- "):
            val=s[2:].strip()
            if section in data and sub in data[section]:
                data[section][sub].append(val)
    return data

d=parse(path)
rules=[]
if d["direct"]["domains"]:
    rules.append({"domain_suffix": d["direct"]["domains"], "outbound": direct_tag})
if d["proxy"]["domains"]:
    rules.append({"domain_suffix": d["proxy"]["domains"], "outbound": proxy_tag})
if d["direct"]["ip_cidr"]:
    rules.append({"ip_cidr": d["direct"]["ip_cidr"], "outbound": direct_tag})
final = proxy_tag if d["final"]=="proxy" else direct_tag
print(json.dumps({"rules":rules,"final":final}))
PY
)"

log "Сгенерированные правила:"
echo "$RULES_JSON" | jq .

BAK="$(backup_file "$SINGBOX_CONFIG")"
TMP="$(mktemp)"
jq --argjson r "$RULES_JSON" '
  .route = (.route // {})
  # Сохраняем служебные правила (dns/protocol/inbound-based), заменяем только
  # managed-правила маршрутизации по доменам/IP.
  | .route.rules = ([ (.route.rules // [])[] | select(has("protocol") or has("inbound")) ] + $r.rules)
  | .route.final = $r.final
' "$SINGBOX_CONFIG" > "$TMP"
mv "$TMP" "$SINGBOX_CONFIG"

# Валидация
if command -v sing-box >/dev/null 2>&1; then
  if ! sing-box check -c "$SINGBOX_CONFIG" >/dev/null 2>&1; then
    warn "sing-box check не прошёл — откат"; cp -a "$BAK" "$SINGBOX_CONFIG"; die "конфиг невалиден, изменения отменены"
  fi
else
  jq empty "$SINGBOX_CONFIG" || { cp -a "$BAK" "$SINGBOX_CONFIG"; die "JSON невалиден, откат"; }
  warn "бинарь sing-box не найден — проверил только JSON"
fi
ok "маршрутизация применена к $SINGBOX_CONFIG"

if [ "$RELOAD" -eq 1 ]; then
  log "перезапуск $SINGBOX_SERVICE"
  systemctl restart "$SINGBOX_SERVICE" && ok "$SINGBOX_SERVICE перезапущен" || warn "перезапустите вручную"
else
  warn "перезапуск пропущен (--no-reload)."
fi
