# Создание inbound VLESS + Reality в 3x-ui

Reality — самый стабильный и незаметный протокол на сегодня: не требует своего
домена и сертификата, маскируется под чужой реальный сайт (SNI). Одинаково
работает в Shadowrocket и Hiddify.

## Шаги в панели

1. Зайди в панель: `http://62.60.236.230:<ПОРТ_ПАНЕЛИ>/<webBasePath>`
   (порт и путь панель показала при установке).
2. **Inbounds → Add Inbound**.
3. Заполни:
   - **Remark**: `kim` (любое имя).
   - **Protocol**: `vless`.
   - **Port**: `443` (рекомендуется — реже режется провайдером).
   - **Listen IP**: оставь пустым (слушать все интерфейсы).
4. **Security**: выбери **Reality**.
   - **uTLS / Fingerprint**: `chrome`.
   - **Dest (target)**: `www.microsoft.com:443`
     (или другой крупный «живой» сайт: `www.cloudflare.com:443`,
     `www.nvidia.com:443`).
   - **SNI / Server Names**: тот же домен без порта, напр. `www.microsoft.com`.
   - **Public/Private key**: нажми кнопку **Get New Cert / генерации ключей** —
     панель сгенерит пару Reality-ключей сама.
   - **shortIds**: нажми сгенерировать (оставь как есть).
5. **Flow** (в разделе клиента): `xtls-rprx-vision`.
6. **Save**.

## Открыть порт в фаерволе
```bash
ufw allow 443/tcp
```

## Получить ссылку/QR
В списке inbound нажми на иконку **«Подключиться» / QR** → скопируй
`vless://...` и импортируй в клиент (см. `docs/clients.md`).

## После создания
Включи принудительный IPv4 (если ещё не сделал):
```bash
sudo bash scripts/03-ipv4-outbound.sh
```
И проверь сервер:
```bash
sudo bash scripts/diagnose.sh
```
