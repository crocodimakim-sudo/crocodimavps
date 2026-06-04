# Стабильная настройка VPS под прокси (3x-ui + VLESS Reality)

Сервер: **HELs-1**, Helsinki · `62.60.236.230` · Ubuntu 26.04 · 1 CPU / 2 GB / 30 GB.

Цель: чтобы прокси работал стабильно и на телефоне (Shadowrocket), и на ПК
(Hiddify), без обрывов и без **403** от Anthropic/Claude.

## Что было не так
- Клиент/сервер ходил через **IPv6** → Anthropic отдавал **403**
  (IPv6-диапазоны хостеров часто в блок-листах).
- Соединение «**отваливалось**» — типичные причины: сбитое время сервера
  (Reality чувствителен к часам), нестабильный IPv6, включённый Mux, нет BBR.

## Что делает эта настройка
1. Точное время (NTP/chrony) — Reality перестаёт рвать хендшейк.
2. BBR + тюнинг TCP + keepalive — меньше обрывов.
3. Принудительный **IPv4** на сервере (Xray freedom → `ForceIPv4`) и приоритет
   IPv4 в резолвере — **лечит 403**.
4. Фаервол (ufw).
5. Панель 3x-ui с протоколом **VLESS + Reality** — общий конфиг для обоих клиентов.

---

## Установка (выполняется на сервере по SSH)

```bash
ssh root@62.60.236.230

# 1. Забираем репозиторий
apt-get update -y && apt-get install -y git
git clone https://github.com/crocodimakim-sudo/crocodimavps.git
cd crocodimavps

# 2. Подготовка системы (NTP, BBR, IPv4-приоритет, фаервол)
sudo bash scripts/01-system-prep.sh

# 3. Установка панели 3x-ui  (ЗАПИШИ логин/пароль/порт из вывода!)
sudo bash scripts/02-install-3xui.sh

# 4. Открываем порты (панель + 443 под inbound)
ufw allow 443/tcp
ufw allow <ПОРТ_ПАНЕЛИ>/tcp

# 5. Создаём inbound VLESS+Reality в панели
#    -> см. docs/server-inbound.md

# 6. Принудительный IPv4 в Xray (лечит 403)
sudo bash scripts/03-ipv4-outbound.sh

# 7. Диагностика — всё ли хорошо
sudo bash scripts/diagnose.sh
```

## Дальше — клиенты
- **Shadowrocket / Hiddify**: импорт ссылки и фикс IPv6 на ПК →
  [`docs/clients.md`](docs/clients.md)
- **Создание inbound в панели** → [`docs/server-inbound.md`](docs/server-inbound.md)
- **Проблемы (403 / обрывы / handshake)** → [`docs/troubleshooting.md`](docs/troubleshooting.md)

---

## ⚠️ Безопасность
Пароль root и строка `6UkZN6ViTuZL` были видны на скриншотах. После настройки
**смени пароль root** (`passwd`) и по возможности перейди на вход по SSH-ключу.
Логин/пароль панели 3x-ui тоже держи в секрете и поставь нестандартный
`webBasePath` (через `x-ui` → меню).

## Структура
```
scripts/
  01-system-prep.sh     # NTP, BBR, IPv4-приоритет, ufw
  02-install-3xui.sh    # установка панели
  03-ipv4-outbound.sh   # Xray freedom -> ForceIPv4 (фикс 403)
  diagnose.sh           # диагностика сервера
docs/
  server-inbound.md     # как создать VLESS+Reality в панели
  clients.md            # Shadowrocket + Hiddify (фикс IPv6 на ПК)
  troubleshooting.md    # разбор ошибок
```
