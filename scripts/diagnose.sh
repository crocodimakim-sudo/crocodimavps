#!/usr/bin/env bash
#
# diagnose.sh — Быстрая диагностика сервера, когда "отваливается" или 403.
# Запуск:  sudo bash diagnose.sh
#
set -uo pipefail
line(){ printf '\n\033[1;36m==== %s ====\033[0m\n' "$*"; }

line "ВРЕМЯ (для Reality расхождение должно быть < 1 сек)"
timedatectl 2>/dev/null | grep -E 'Local|Universal|synchronized|NTP' || date -u
chronyc tracking 2>/dev/null | grep -E 'System time|Leap' || true

line "BBR"
echo "congestion_control = $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
echo "qdisc default      = $(sysctl -n net.core.default_qdisc 2>/dev/null)"

line "ВНЕШНИЙ IP ПО IPv4 и IPv6"
echo -n "IPv4: "; curl -4 -s --max-time 8 https://api.ipify.org || echo "(нет IPv4!)"; echo
echo -n "IPv6: "; curl -6 -s --max-time 8 https://api64.ipify.org || echo "(нет IPv6 — это нормально)"; echo

line "ПРОВЕРКА ДОСТУПА К ANTHROPIC ПО IPv4 (должно быть НЕ 403)"
echo -n "claude.ai (IPv4): "; curl -4 -s -o /dev/null -w '%{http_code}\n' --max-time 10 https://claude.ai || echo "ошибка"
echo -n "api.anthropic.com (IPv4): "; curl -4 -s -o /dev/null -w '%{http_code}\n' --max-time 10 https://api.anthropic.com || echo "ошибка"

line "СТАТУС ПАНЕЛИ / XRAY"
x-ui status 2>/dev/null || systemctl status x-ui --no-pager -l 2>/dev/null | head -20

line "СЛУШАЮЩИЕ ПОРТЫ"
ss -tlnp 2>/dev/null | grep -E 'xray|x-ui|LISTEN' | head -30

line "FREEDOM OUTBOUND В ШАБЛОНЕ (должно быть ForceIPv4)"
if [[ -f /etc/x-ui/x-ui.db ]] && command -v sqlite3 >/dev/null && command -v jq >/dev/null; then
  sqlite3 /etc/x-ui/x-ui.db "SELECT value FROM settings WHERE key='xrayTemplateConfig';" \
    | jq -c '.outbounds[]? | select(.protocol=="freedom") | {tag, domainStrategy: .settings.domainStrategy}' 2>/dev/null \
    || echo "не удалось прочитать шаблон"
else
  echo "sqlite3/jq не установлены или нет БД"
fi

line "ФАЕРВОЛ"
ufw status 2>/dev/null || echo "ufw не активен"

echo
echo "Если api.anthropic.com по IPv4 != 403, а проблема осталась — значит клиент"
echo "(Hiddify) сам уходит в IPv6. См. docs/clients.md (раздел Hiddify)."
