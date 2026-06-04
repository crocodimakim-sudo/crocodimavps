#!/usr/bin/env bash
#
# 02-install-3xui.sh — Установка панели 3x-ui (Xray) от MHSanaei.
#
# 3x-ui — это веб-панель управления Xray: создаёшь inbound (VLESS Reality),
# а панель выдаёт готовую ссылку/QR, которые одинаково импортируются и в
# Shadowrocket, и в Hiddify.
#
# Запуск:  sudo bash 02-install-3xui.sh
#
# Установщик официальный и интерактивный: он сам сгенерирует логин/пароль/порт
# панели и покажет их в конце. ОБЯЗАТЕЛЬНО запиши их.
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Запусти от root:  sudo bash $0" >&2
  exit 1
fi

echo "==> Ставлю 3x-ui (официальный установщик MHSanaei)"
echo "    Запиши логин/пароль/порт, которые он покажет в конце!"
echo
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)

cat <<'EOF'

================================================================
3x-ui установлен.

Полезные команды управления панелью:
  x-ui            # интерактивное меню (сменить логин/пароль/порт, рестарт)
  x-ui status     # статус
  x-ui restart    # перезапуск
  x-ui settings   # показать текущие настройки доступа к панели

Не забудь открыть порт панели в фаерволе, например:
  ufw allow <ПОРТ_ПАНЕЛИ>/tcp

Дальше:
  - Зайди в панель:  http://62.60.236.230:<ПОРТ>/<webBasePath>
  - Создай inbound VLESS + Reality (см. docs/server-inbound.md)
  - Включи ForceIPv4:  sudo bash 03-ipv4-outbound.sh
================================================================
EOF
