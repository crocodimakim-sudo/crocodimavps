#!/usr/bin/env bash
# Общие функции. Подключается через: source "$(dirname "$0")/lib.sh"
set -euo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "$_here/config.sh"

log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "нужна утилита: $1 (установите её)"; }

# Генерация UUID с несколькими fallback'ами (xray -> uuidgen -> ядро -> python).
gen_uuid() {
  if command -v xray >/dev/null 2>&1; then xray uuid
  elif command -v uuidgen >/dev/null 2>&1; then uuidgen
  elif [ -r /proc/sys/kernel/random/uuid ]; then cat /proc/sys/kernel/random/uuid
  elif command -v python3 >/dev/null 2>&1; then python3 -c 'import uuid;print(uuid.uuid4())'
  else die "нет способа сгенерировать UUID (нет xray/uuidgen/python3)"; fi
}

require_root() {
  [ "$(id -u)" -eq 0 ] || die "нужен root (запустите через sudo)"
}

# Бэкап файла с таймштампом. Возвращает путь бэкапа.
backup_file() {
  local f="$1"
  [ -f "$f" ] || die "файл не найден: $f"
  local ts; ts="$(date +%Y%m%d-%H%M%S)"
  local bak="${f}.bak.${ts}"
  cp -a "$f" "$bak"
  log "бэкап: $bak"
  printf '%s' "$bak"
}

# Валидация JSON-конфига xray. Откатывает из бэкапа при ошибке.
xray_validate_or_rollback() {
  local cfg="$1" bak="$2"
  if command -v xray >/dev/null 2>&1; then
    if ! xray -test -config "$cfg" >/dev/null 2>&1; then
      warn "xray -test не прошёл, откатываю из бэкапа"
      cp -a "$bak" "$cfg"
      die "конфиг невалиден, изменения отменены"
    fi
  else
    # xray нет (например, редактируем не на сервере) — хотя бы проверим JSON
    jq empty "$cfg" 2>/dev/null || { cp -a "$bak" "$cfg"; die "JSON невалиден, откат"; }
    warn "бинарь xray не найден — проверил только синтаксис JSON"
  fi
}

# Найти индекс REALITY-inbound в конфиге xray (первый vless+reality).
xray_reality_inbound_index() {
  local cfg="$1"
  jq -r '[.inbounds | to_entries[] | select(.value.protocol=="vless" and (.value.streamSettings.security=="reality")) | .key][0] // empty' "$cfg"
}

# Проверка имени друга: латиница/цифры/дефис/подчёркивание.
valid_name() { [[ "$1" =~ ^[a-zA-Z0-9_-]{1,32}$ ]]; }

ensure_secrets_store() {
  mkdir -p "$SECRETS_DIR"
  chmod 700 "$SECRETS_DIR" 2>/dev/null || true
  [ -f "$FRIENDS_SECRETS" ] || { : > "$FRIENDS_SECRETS"; chmod 600 "$FRIENDS_SECRETS"; }
}
