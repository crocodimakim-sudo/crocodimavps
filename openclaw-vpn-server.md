# Полное описание сервера — OpenClaw + VPN

> Для передачи другому агенту.
>
> ⚠️ **Секреты замаскированы плейсхолдерами** (`<...>`). Реальные значения хранятся
> на сервере в `/root/.openclaw/openclaw.json`, `/etc/sing-box/config.json`
> и `/root/.ssh/`. Не публикуйте живые ключи в этом репозитории.

---

## 1. Системная информация

| Параметр | Значение |
|----------|----------|
| **OS** | Ubuntu 24.04.3 LTS (Noble Numbat) |
| **Kernel** | Linux 6.8.0-90-generic |
| **Hostname** | iZt4ndyj7qpgleoeq8kioxZ |
| **CPU** | Intel Xeon Platinum (2 vCPU) |
| **RAM** | 7.1 GB |
| **Disk** | 40 GB (15G used, 23G free) |
| **IP (eth0)** | 10.184.28.145 (Alibaba Cloud internal) |
| **User** | root |
| **Home** | /root |
| **Shell** | /bin/bash |

**Важно:** Это Alibaba Cloud VPS. Внешний IP — через NAT/проброс.

---

## 2. Ключевые сервисы и порты

| Сервис | Порт | Описание |
|--------|------|----------|
| SSH | 0.0.0.0:22 | OpenSSH, root login разрешён, PasswordAuth NO (только ключи) |
| OpenClaw Gateway | 127.0.0.1:18789 / 127.0.0.1:18791 | Основной процесс (PID 205614) |
| Sing-box | 127.0.0.1:10808 | SOCKS/HTTP mixed inbound (VPN клиент) |
| PostgreSQL | 127.0.0.1:5432 / 127.0.1.1:5432 | База данных (версия 16) |
| DNS | 127.0.0.53:53, 127.0.0.54:53 | systemd-resolved |

---

## 3. OpenClaw Конфигурация

### Версия
- **OpenClaw Version:** 2026.4.14
- **Install Path:** /usr/lib/node_modules/openclaw/
- **Config:** /root/.openclaw/openclaw.json
- **Workspace:** /root/.openclaw/workspace/
- **Logs:** /root/.openclaw/logs/openclaw.log

### Модель (единственная)
- **Provider:** kimi-coding
- **Model:** k2p6 (Kimi K2.6)
- **API Key:** `<KIMI_API_KEY>`
- **Base URL:** https://agent-gw.kimi.com/coding
- **Context Window:** 131072
- **Max Tokens:** 32768
- **Thinking:** high (по умолчанию)
- **Heartbeat:** каждые 60 минут

### Плагины (расширения)
| Плагин | Версия | Путь | Статус |
|--------|--------|------|--------|
| openclaw-lark (飞书) | 2026.4.8 | /root/.openclaw/extensions/openclaw-lark | ✅ Активен |
| dingtalk-connector | 0.8.13 | /root/.openclaw/extensions/dingtalk-connector | ✅ Активен |
| wecom-openclaw-plugin | 2026.4.23 | /root/.openclaw/extensions/wecom-openclaw-plugin | ✅ Активен |
| openclaw-weixin (微信) | 2.1.10 | /root/.openclaw/extensions/openclaw-weixin | ✅ Активен |
| openclaw-qqbot (QQ) | 1.7.1 | /root/.openclaw/extensions/openclaw-qqbot | ✅ Активен |
| kimi-claw | - | /root/.openclaw/extensions/kimi-claw | ✅ Активен |
| kimi-search | - | /root/.openclaw/extensions/kimi-search | ✅ Активен |

### Каналы (channels)
- **kimi-claw** — основной канал, через который идёт общение
- **openclaw-weixin** — WeChat (微信) канал, настроен 2026-05-10
- **openclaw-qqbot** — QQ бот
- **openclaw-lark** — 飞书 (Lark/Feishu)
- **wecom-openclaw-plugin** — 企业微信
- **dingtalk-connector** — 钉钉

### Браузер
- **Chrome:** /usr/bin/google-chrome
- **Headless:** true
- **NoSandbox:** true
- **Default Profile:** openclaw

### Tools Profile: **full**

---

## 4. VPN / Прокси конфигурация

### Основной VPN: HELs-VLESS (AEZA/Hetzner)
| Параметр | Значение |
|----------|----------|
| **Server** | 62.60.236.230 |
| **Port** | 443 |
| **Protocol** | VLESS + REALITY |
| **UUID** | `<VLESS_UUID>` |
| **Flow** | xtls-rprx-vision |
| **SNI** | www.google.com |
| **Public Key** | `<REALITY_PUBLIC_KEY>` |
| **Short ID** | `<REALITY_SHORT_ID>` |
| **Fingerprint** | chrome (utls) |
| **IP Strategy** | ipv4_only |

### Sing-box конфигурация (локальная)
- **Config:** /etc/sing-box/config.json
- **Inbound:** mixed SOCKS/HTTP proxy на 127.0.0.1:10808
- **Outbound:** HELs-VLESS (через AEZA сервер)
- **DNS:** Google DNS через VPN, local DNS (223.5.5.5) direct
- **Route Rules:**
  - DNS трафик → через VPN
  - Приватные IP (192.168.*, 10.*, 172.*) → DIRECT
  - DeepSeek, Kimi (deepseek.com, kimi.moonshot.cn) → DIRECT

### Дополнительные клиенты
- **Hiddify (iPhone/Android):** использует JSON подписку
- **Shadowrocket (iPhone):** VLESS URI или .conf файл
- **JSON Subscription:** http://62.60.236.230:8080/sing-box.json (Python HTTP server)
- **VLESS URI:** `vless://<VLESS_UUID>@62.60.236.230:443?security=reality&flow=xtls-rprx-vision&sni=www.google.com&fp=chrome&pbk=<REALITY_PUBLIC_KEY>&sid=<REALITY_SHORT_ID>&type=tcp&headerType=none#HELs-VLESS`

---

## 5. SSH конфигурация

- **Port:** 22 (стандартный)
- **Root Login:** YES (PermitRootLogin yes)
- **Password Authentication:** NO (только ключи)
- **Authorized Keys:** `<SSH_AUTHORIZED_KEY>` (RSA, см. /root/.ssh/authorized_keys)
- **Server Key (ed25519):** `<SSH_HOST_KEY>` (kimi-claw, публичный host-ключ)

---

## 6. Известные проблемы и их история

### 🔴 КРИТИЧНАЯ: Anthropic / Claude Code блокировка
**Статус:** НЕ РЕШЕНО

- **Проблема:** IP сервера (AEZA/Hetzner) блокируется Anthropic — получаем 403 Forbidden
- **Проверено:** Через VPN (62.60.236.230) — Anthropic тоже не работает
- **Проверено:** Через DIRECT (домашний IP РФ) — работает, но пользователь **ЗАПРЕТИЛ** это
- **Железное правило пользователя:** `claude.ai`, `claude.com`, `anthropic.com` — **ВСЕГДА через VPN (HELs-VLESS)**
- **Правило:** НИКОГДА не предлагать DIRECT для Anthropic — это категоричное правило
- **Варианты решения:**
  - Cloudflare WARP (warp-cli на сервере + SOCKS5)
  - Другой VPS-провайдер (не Hetzner/AEZA)
  - Residential proxy

### 🟡 WARP / Cloudflare не подключается
**Статус:** НЕ РЕШЕНО (2026-06-04)
- Пробовались: `gso: false`, убран IPv6, добавлен `ip_cidr` для endpoint → direct
- Проблема: неизвестная версия sing-box в Hiddify, возможно не поддерживает `wireguard` outbound с `reserved`

### 🟡 Hiddify IPv6 проблема
- Hiddify иногда подключается к `2a01:...` (IPv6) вместо `62.60.236.230`
- Причина: сервер имеет AAAA DNS запись, Hiddify резолвит IPv6
- Пользователь отказывается от ручной конфигурации, хочет только линки/подписки

### 🟢 Решённые проблемы
- **Claude.com OAuth редирект:** Исправлено — убрано правило DIRECT для claude/anthropic из конфигов
- **Сервер перезагружен:** 2026-06-02 ~14:41 MSK — xray запущен, работает
- **Sing-box JSON подписка:** Создана и работает на http://62.60.236.230:8080/sing-box.json

---

## 7. Файловая структура (ключевые директории)

```
/root/
├── .openclaw/                  # Основная директория OpenClaw
│   ├── openclaw.json           # Главный конфиг
│   ├── logs/                   # Логи
│   ├── workspace/              # Рабочая область агента
│   │   ├── AGENTS.md
│   │   ├── IDENTITY.md
│   │   ├── SOUL.md
│   │   ├── USER.md
│   │   ├── MEMORY.md           # Долгосрочная память
│   │   ├── HEARTBEAT.md
│   │   ├── vpn-configs.md
│   │   ├── memory/             # Дневные заметки
│   │   └── skills/             # Кастомные скиллы
│   ├── extensions/             # Плагины
│   ├── agents/                 # Агенты (main, kimi-claw)
│   ├── plugins/                # Плагин-конфиги
│   ├── cron/                   # Cron задачи
│   └── browser/                # Браузер профили
├── .ssh/                       # SSH ключи
└── sing-box.json               # (если есть) Конфиг для подписки
```

---

## 8. Заметки о пользователе (из USER.md)

- **Имя:** Не указано (пусто в USER.md)
- **Как обращаться:** Не указано
- **Часовой пояс:** Не указано (но сообщения в GMT+8)
- **Предпочтения:**
  - Хочет только линки/подписки для VPN, не ручную конфигурацию
  - Категоричен по поводу Anthropic — всегда через VPN
  - Работает с темой фиброцемента (fiber_cement_*.md файлы в workspace)

---

## 9. Проекты в workspace

- **bbgl_parser** — парсер (Python проект)
- **fiber_cement_china.md** / **fiber_cement_russia.md** / **fiber_cement_world.md** — исследования фиброцемента
- **fibrocement_technical_certificates.csv/.md** — технические сертификаты
- **research/** — директория исследований

---

## 10. API ключи и токены (🔒 чувствительные — хранятся на сервере, НЕ в репозитории)

| Сервис | Плейсхолдер | Где используется | Реальное значение |
|--------|-------------|------------------|-------------------|
| **Kimi API** | `<KIMI_API_KEY>` | Везде: models, memorySearch, kimi-search plugin, gateway | /root/.openclaw/openclaw.json |

---

## 11. Что нужно знать другому агенту

1. **Этот сервер — Alibaba Cloud VPS**, не AEZA/Hetzner (хотя VPN выходит через AEZA)
2. **OpenClaw Gateway запущен как systemd-сервис** (PID 205614, запущен 2026-06-01)
3. **PostgreSQL 16** работает локально для OpenClaw
4. **Sing-box** работает как VPN-клиент (не сервер!), подключается к AEZA VPS
5. **Главная нерешённая проблема:** Anthropic блокирует IP, и VPN тоже не помогает
6. **Пользователь хочет:** решение для Anthropic без DIRECT через домашний IP
7. **Не перезагружай Gateway без предупреждения** — пользователь должен знать
8. **Все конфиги хранятся в /root/.openclaw/openclaw.json** — бэкапы есть (.bak, .bak.1-4)

---

*Документ создан: 2026-06-07*
*Для передачи другому агенту — полное описание инфраструктуры*
