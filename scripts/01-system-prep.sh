#!/usr/bin/env bash
#
# 01-system-prep.sh — Подготовка VPS к стабильной работе прокси (Xray/3x-ui).
#
# Что делает (всё идемпотентно, можно запускать повторно):
#   1. Обновляет систему и ставит базовые пакеты.
#   2. Включает точную синхронизацию времени (NTP) — КРИТИЧНО для VLESS Reality:
#      при расхождении часов > ~90 сек Reality-хендшейк рвётся и соединение
#      "отваливается".
#   3. Включает BBR + fq и тюнит TCP — меньше обрывов, стабильнее скорость.
#   4. Выставляет приоритет IPv4 над IPv6 на уровне резолвера (/etc/gai.conf).
#      Это часть лечения "подключается через IPv6 / 403 от Claude".
#   5. Настраивает фаервол (ufw): SSH + порты, которые ты укажешь.
#
# Запуск:  sudo bash 01-system-prep.sh
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Запусти от root:  sudo bash $0" >&2
  exit 1
fi

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Система и базовые пакеты
# ---------------------------------------------------------------------------
log "Обновляю пакеты"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget socat ca-certificates jq ufw chrony \
  iproute2 dnsutils tar

# ---------------------------------------------------------------------------
# 2. Точное время (NTP) — лечит обрывы Reality
# ---------------------------------------------------------------------------
log "Включаю синхронизацию времени"
timedatectl set-ntp true || true
# chrony как надёжный демон NTP (на случай если timesyncd выключен)
systemctl enable --now chrony 2>/dev/null || systemctl enable --now chronyd 2>/dev/null || true
sleep 2
timedatectl status || true
echo "Текущее время сервера: $(date -u)  (UTC)"

# ---------------------------------------------------------------------------
# 3. BBR + сетевой тюнинг
# ---------------------------------------------------------------------------
log "Включаю BBR и тюнинг TCP"
SYSCTL=/etc/sysctl.d/99-proxy-tuning.conf
cat > "$SYSCTL" <<'EOF'
# --- Управление перегрузкой: BBR + fq ---
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# --- Буферы и очереди (стабильность под нагрузкой) ---
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 8192
net.core.somaxconn = 8192
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# --- Меньше обрывов простаивающих соединений (keepalive) ---
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5

# --- Прочее ---
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.ip_forward = 1
fs.file-max = 1048576
EOF
sysctl --system >/dev/null
echo "Алгоритм перегрузки: $(sysctl -n net.ipv4.tcp_congestion_control)"

# Лимит открытых файлов (много соединений)
LIMITS=/etc/security/limits.d/99-proxy.conf
cat > "$LIMITS" <<'EOF'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

# ---------------------------------------------------------------------------
# 4. Приоритет IPv4 над IPv6 (часть лечения "IPv6 / 403")
# ---------------------------------------------------------------------------
log "Выставляю приоритет IPv4 над IPv6 в резолвере"
# Раскомментируем/добавим строку precedence так, чтобы IPv4-mapped адреса
# имели высокий приоритет — система будет предпочитать IPv4.
if grep -q '^\s*precedence ::ffff:0:0/96' /etc/gai.conf 2>/dev/null; then
  sed -i 's|^\s*precedence ::ffff:0:0/96.*|precedence ::ffff:0:0/96  100|' /etc/gai.conf
else
  echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
fi
echo "Готово. /etc/gai.conf обновлён."
echo "ВАЖНО: окончательно IPv6-обход для Claude/Anthropic лечится в Xray"
echo "       (outbound freedom -> domainStrategy = ForceIPv4). См. 03-ipv4-outbound.sh"

# ---------------------------------------------------------------------------
# 5. Фаервол
# ---------------------------------------------------------------------------
log "Настраиваю фаервол (ufw)"
SSH_PORT="${SSH_PORT:-22}"
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp" comment 'SSH'
# Порты прокси и панели добавим отдельно (см. ниже / README).
# Открой нужные порты, например:
#   ufw allow 443/tcp        # порт VLESS Reality inbound
#   ufw allow 2053/tcp       # порт панели 3x-ui (поставь свой)
echo "y" | ufw enable
ufw status verbose

log "Готово. Система подготовлена."
echo
echo "Дальше:"
echo "  1) Открой порты прокси и панели:  ufw allow <PORT>/tcp"
echo "  2) Установи панель:               sudo bash 02-install-3xui.sh"
echo "  3) Включи ForceIPv4 в Xray:        sudo bash 03-ipv4-outbound.sh"
