#!/usr/bin/env bash
# Несекретные параметры. Пути к конфигам и публичные данные VPN.
# Переопределяются переменными окружения (например, XRAY_CONFIG=/path scripts/...).

# --- VPN-сервер AEZA (xray VLESS+REALITY) ---
: "${VPN_HOST:=62.60.236.230}"
: "${VPN_PORT:=443}"
: "${VPN_SNI:=www.google.com}"
: "${VPN_FLOW:=xtls-rprx-vision}"
: "${VPN_FP:=chrome}"
# Публичный ключ REALITY (это ПУБЛИЧНАЯ часть, попадает в каждую ссылку — не секрет).
: "${VPN_PBK:=D2SosmZ7KdzDaP4SBzgFDBscdg3fcgm6M4fKg2KBbCw}"
# Путь к конфигу xray на сервере AEZA (типичные варианты).
: "${XRAY_CONFIG:=/usr/local/etc/xray/config.json}"
: "${XRAY_SERVICE:=xray}"

# --- Alibaba VPS (sing-box клиент) ---
: "${SINGBOX_CONFIG:=/etc/sing-box/config.json}"
: "${SINGBOX_SERVICE:=sing-box}"
: "${OPENCLAW_SERVICE:=openclaw-gateway}"

# --- Хранилище состояния ---
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${STATE_DIR:=$REPO_ROOT/state}"
: "${SECRETS_DIR:=$REPO_ROOT/.secrets}"
: "${FRIENDS_REGISTRY:=$STATE_DIR/friends.yaml}"
: "${FRIENDS_SECRETS:=$SECRETS_DIR/friends-secrets.tsv}"  # name<TAB>uuid<TAB>shortid
