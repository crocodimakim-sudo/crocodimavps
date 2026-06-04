#!/usr/bin/env bash
###############################################################################
#  setup.sh — всё-в-одном: стабильная настройка VPS под прокси
#  3x-ui + VLESS Reality, с фиксом IPv6/403 и обрывов.
#
#  Сервер: HELs-1 (Helsinki) 62.60.236.230 · Ubuntu 26.04
#
#  ЧТО ДЕЛАЕТ (идемпотентно, можно запускать повторно):
#    1. Обновляет систему, ставит пакеты.
#    2. Точное время (NTP/chrony) — лечит обрывы VLESS Reality.
#    3. BBR + тюнинг TCP + keepalive — меньше обрывов.
#    4. Приоритет IPv4 в резолвере.
#    5. Фаервол ufw (SSH + 443 + порт панели).
#    6. Ставит панель 3x-ui (если ещё не стоит).
#    7. Принудительный IPv4 в Xray (freedom -> ForceIPv4) — ЛЕЧИТ 403 от Claude.
#    8. Диагностика в конце.
#
#  ЗАПУСК на сервере от root:
#    bash setup.sh
#
#  После установки панели — создай inbound VLESS+Reality в веб-панели
#  (инструкция печатается в конце), затем переподключи клиент.
###############################################################################
set -euo pipefail

PANEL_PORT_DEFAULT=2053     # порт панели, который откроем в фаерволе
INBOUND_PORT=443            # порт под VLESS Reality inbound
SSH_PORT="${SSH_PORT:-22}"

if [[ $EUID -ne 0 ]]; then
  echo "Запусти от root:  sudo bash $0" >&2
  exit 1
fi

log()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!  %s\033[0m\n' "$*"; }

###############################################################################
log "[1/7] Обновляю систему и ставлю пакеты"
###############################################################################
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget socat ca-certificates jq ufw chrony \
  iproute2 dnsutils tar sqlite3 git

###############################################################################
log "[2/7] Точное время (NTP) — лечит обрывы Reality"
###############################################################################
timedatectl set-ntp true || true
systemctl enable --now chrony 2>/dev/null || systemctl enable --now chronyd 2>/dev/null || true
sleep 2
timedatectl status 2>/dev/null | grep -E 'Local|Universal|synchronized|NTP' || date -u

###############################################################################
log "[3/7] BBR + тюнинг TCP"
###############################################################################
cat > /etc/sysctl.d/99-proxy-tuning.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 8192
net.core.somaxconn = 8192
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.ip_forward = 1
fs.file-max = 1048576
EOF
sysctl --system >/dev/null
echo "congestion_control = $(sysctl -n net.ipv4.tcp_congestion_control)"

cat > /etc/security/limits.d/99-proxy.conf <<'EOF'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

###############################################################################
log "[4/7] Приоритет IPv4 над IPv6 в резолвере"
###############################################################################
if grep -q '^\s*precedence ::ffff:0:0/96' /etc/gai.conf 2>/dev/null; then
  sed -i 's|^\s*precedence ::ffff:0:0/96.*|precedence ::ffff:0:0/96  100|' /etc/gai.conf
else
  echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
fi
echo "/etc/gai.conf обновлён (IPv4 в приоритете)."

###############################################################################
log "[5/7] Фаервол ufw"
###############################################################################
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp"      comment 'SSH'
ufw allow "${INBOUND_PORT}/tcp"  comment 'VLESS inbound'
ufw allow "${PANEL_PORT_DEFAULT}/tcp" comment '3x-ui panel'
echo "y" | ufw enable
ufw status verbose

###############################################################################
log "[6/7] Панель 3x-ui"
###############################################################################
if command -v x-ui >/dev/null 2>&1; then
  echo "3x-ui уже установлена — пропускаю установку."
  echo "Сменить логин/пароль/порт можно командой:  x-ui"
else
  warn "Сейчас запустится официальный установщик 3x-ui."
  warn "Он сгенерит ЛОГИН/ПАРОЛЬ/ПОРТ панели — ОБЯЗАТЕЛЬНО запиши их!"
  sleep 2
  bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
fi

###############################################################################
log "[7/7] Принудительный IPv4 в Xray (лечит 403 от Claude/Anthropic)"
###############################################################################
DB="/etc/x-ui/x-ui.db"
if [[ -f "$DB" ]]; then
  cp -a "$DB" "${DB}.bak.$(date +%Y%m%d%H%M%S)"
  TMP_IN="$(mktemp)"; TMP_OUT="$(mktemp)"
  sqlite3 "$DB" "SELECT value FROM settings WHERE key='xrayTemplateConfig';" > "$TMP_IN"
  if [[ -s "$TMP_IN" ]]; then
    jq '
      if any(.outbounds[]?; .protocol=="freedom")
      then (.outbounds |= map(if .protocol=="freedom"
            then (.settings = (.settings // {}) + {"domainStrategy":"ForceIPv4"})
            else . end))
      else (.outbounds += [{"tag":"direct","protocol":"freedom",
            "settings":{"domainStrategy":"ForceIPv4"}}])
      end
    ' "$TMP_IN" > "$TMP_OUT"
    if jq -e . "$TMP_OUT" >/dev/null 2>&1; then
      sqlite3 "$DB" "UPDATE settings SET value = readfile('$TMP_OUT') WHERE key='xrayTemplateConfig';"
      x-ui restart >/dev/null 2>&1 || systemctl restart x-ui || true
      echo "Готово: freedom outbound -> ForceIPv4."
    else
      warn "Не удалось собрать валидный JSON — пропускаю патч outbound."
    fi
  else
    warn "В БД ещё нет шаблона Xray. Зайди в панель один раз и перезапусти setup.sh."
  fi
  rm -f "$TMP_IN" "$TMP_OUT"
else
  warn "БД 3x-ui не найдена ($DB). Установи панель и перезапусти setup.sh."
fi

###############################################################################
log "ДИАГНОСТИКА"
###############################################################################
echo -n "Внешний IPv4: "; curl -4 -s --max-time 8 https://api.ipify.org || echo "(нет!)"; echo
echo -n "api.anthropic.com по IPv4 (НЕ должно быть 403): "
curl -4 -s -o /dev/null -w '%{http_code}\n' --max-time 10 https://api.anthropic.com || echo "ошибка"
echo "freedom outbound:"
sqlite3 "$DB" "SELECT value FROM settings WHERE key='xrayTemplateConfig';" 2>/dev/null \
  | jq -c '.outbounds[]? | select(.protocol=="freedom") | {tag, domainStrategy: .settings.domainStrategy}' 2>/dev/null \
  || echo "(нет данных)"

cat <<EOF

================================================================
ГОТОВО. Дальше — вручную в веб-панели:

1) Зайди в панель в браузере:
     http://62.60.236.230:<ПОРТ_ПАНЕЛИ>/<webBasePath>
   (порт/путь панель показала при установке; порт ${PANEL_PORT_DEFAULT} уже открыт
    в фаерволе — если у тебя другой порт, открой его: ufw allow <ПОРТ>/tcp)

2) Inbounds -> Add Inbound:
     Protocol = vless
     Port     = ${INBOUND_PORT}
     Security = Reality
       Dest/Target  = www.microsoft.com:443
       SNI          = www.microsoft.com
       Fingerprint  = chrome
       ключи Reality -> кнопка "сгенерировать"
     Flow (у клиента) = xtls-rprx-vision
   Сохрани.

3) Нажми на inbound -> "Подключиться"/QR -> скопируй ссылку vless://...

4) Импортируй в клиент:
   - iPhone (Shadowrocket): вставь ссылку, подключись.
   - ПК (Hiddify): вставь ссылку, ЗАТЕМ в Настройках конфигурации:
        IPv6                       = Выключить
        Remote DNS domain strategy = ipv4_only
        Direct DNS domain strategy = ipv4_only
        Mux                        = Выключить
        TLS Fragment/Tricks        = Выключить
     -> Переподключись. 403 и обрывы должны пропасть.

БЕЗОПАСНОСТЬ: смени пароль root (passwd) — он светился на скриншоте.
================================================================
EOF
