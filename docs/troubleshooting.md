# Разбор частых проблем

## «Claude Code выдаёт 403» / Anthropic не пускает
**Причина:** трафик уходит в интернет через IPv6, а IPv6-диапазон сервера/клиента
в блок-листе Anthropic/Cloudflare.
**Лечение:**
1. Сервер: `sudo bash scripts/03-ipv4-outbound.sh` (freedom outbound → ForceIPv4).
2. Клиент Hiddify: выключи IPv6, DNS strategy = `ipv4_only` (см. `docs/clients.md`).
3. Проверка на сервере: `curl -4 -s -o /dev/null -w '%{http_code}\n' https://api.anthropic.com`
   → должно быть **НЕ 403** (обычно 200/401/404 — это норм, главное не 403).

## «Постоянно отваливается»
Частые причины по убыванию вероятности:
1. **Часы сервера сбиты** → Reality рвёт хендшейк.
   `timedatectl` / `chronyc tracking` — расхождение должно быть < 1 сек.
   Лечит `scripts/01-system-prep.sh` (chrony + NTP).
2. **IPv6 нестабилен у хостера** → клиент скачет v4/v6. Выключи IPv6 на клиенте.
3. **Mux включён** на клиенте → выключи.
4. **Провайдер режет порт** → перенеси inbound на `443`.
5. **Нет BBR** → проверь `sysctl -n net.ipv4.tcp_congestion_control` = `bbr`.

## «Не подключается вообще / handshake failed»
- Порт inbound не открыт в `ufw` → `ufw allow <PORT>/tcp`.
- Reality **SNI/Dest** недоступен или заблокирован — смени `Dest` на другой живой
  сайт (`www.cloudflare.com:443`, `www.nvidia.com:443`).
- Public key в клиенте не совпадает с серверным — перегенерируй ссылку из панели.
- Время на сервере сбито (см. выше).

## Панель 3x-ui недоступна
- Открой её порт: `ufw allow <ПОРТ_ПАНЕЛИ>/tcp`.
- `x-ui status`, при необходимости `x-ui restart`.
- Забыл логин/порт: `x-ui settings`.

## Полезные команды
```bash
x-ui                 # меню управления панелью
x-ui restart         # рестарт панели+Xray
journalctl -u x-ui -n 100 --no-pager   # логи
ss -tlnp | grep xray # какие порты слушает Xray
sudo bash scripts/diagnose.sh          # полная диагностика
```
