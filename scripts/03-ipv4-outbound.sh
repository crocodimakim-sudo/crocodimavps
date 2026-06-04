#!/usr/bin/env bash
#
# 03-ipv4-outbound.sh — Заставляет Xray ходить в интернет ТОЛЬКО по IPv4.
#
# Это главный фикс твоей проблемы: "подключается через IPv6 и Claude выдаёт 403".
# Многие IPv6-диапазоны хостеров в блок-листах Anthropic/Cloudflare, поэтому
# исходящие через IPv6 ловят 403. Ставим freedom-outbound domainStrategy =
# ForceIPv4 — весь исходящий трафик сервера идёт по IPv4.
#
# Скрипт правит шаблон Xray прямо в БД 3x-ui (/etc/x-ui/x-ui.db), делает бэкап
# и перезапускает панель.  Идемпотентно.
#
# Запуск:  sudo bash 03-ipv4-outbound.sh
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Запусти от root:  sudo bash $0" >&2
  exit 1
fi

DB="/etc/x-ui/x-ui.db"
command -v sqlite3 >/dev/null || { apt-get update -y && apt-get install -y sqlite3; }
command -v jq      >/dev/null || { apt-get update -y && apt-get install -y jq; }

if [[ ! -f "$DB" ]]; then
  echo "Не нашёл БД 3x-ui ($DB). Сначала установи панель: 02-install-3xui.sh" >&2
  exit 1
fi

echo "==> Бэкап БД"
cp -a "$DB" "${DB}.bak.$(date +%Y%m%d%H%M%S)"

echo "==> Читаю шаблон Xray из панели"
TMP_IN="$(mktemp)"; TMP_OUT="$(mktemp)"
sqlite3 "$DB" "SELECT value FROM settings WHERE key='xrayTemplateConfig';" > "$TMP_IN"

if [[ ! -s "$TMP_IN" ]]; then
  echo "В БД нет xrayTemplateConfig — открой панель один раз, чтобы он создался, и повтори." >&2
  exit 1
fi

echo "==> Ставлю domainStrategy=ForceIPv4 для freedom-outbound"
# Если freedom-outbound есть — патчим его; если вдруг нет — добавляем.
jq '
  if any(.outbounds[]?; .protocol=="freedom")
  then (.outbounds |= map(if .protocol=="freedom"
        then (.settings = (.settings // {}) + {"domainStrategy":"ForceIPv4"})
        else . end))
  else (.outbounds += [{"tag":"direct","protocol":"freedom",
        "settings":{"domainStrategy":"ForceIPv4"}}])
  end
' "$TMP_IN" > "$TMP_OUT"

# Проверяем, что получился валидный JSON
jq -e . "$TMP_OUT" >/dev/null

echo "==> Записываю обратно в БД"
# Читаем новое значение прямо из файла (readfile есть в sqlite3 CLI) —
# так не ломаемся на кавычках/спецсимволах в JSON.
sqlite3 "$DB" <<SQL
UPDATE settings SET value = readfile('$TMP_OUT') WHERE key='xrayTemplateConfig';
SQL

rm -f "$TMP_IN" "$TMP_OUT"

echo "==> Перезапускаю 3x-ui / Xray"
x-ui restart || systemctl restart x-ui

echo
echo "Готово. Теперь весь исходящий трафик сервера идёт по IPv4."
echo "Проверь: с сервера должно резолвиться и ходить по IPv4:"
echo "  curl -4 -s https://api.ipify.org ; echo"
