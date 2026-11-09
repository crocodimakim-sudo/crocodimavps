# Агенты отдела: единый источник

Здесь описаны роли **без привязки к платформе**. В шапке у каждой роли:
- `uroven`: light / mid / strong — уровень модели. Конкретные модели заданы в `../instrumenty/modeli.conf`.
- `usilie`: low / medium / high.
- `claude_tools`: список инструментов. В Claude Code это жёсткий допуск, в Codex текстовое правило.

`bash ../sobrat-agentov.sh` собирает из этих файлов:
- `.claude/agents/<name>.md` для Claude Code;
- `.codex/agents/<name>.toml` для Codex;
- `.codex/config.toml`: руководитель на сильной модели.

**Правите роль только здесь**, потом запускаете скрипт. Готовые файлы в `.claude/` и `.codex/` руками не трогаете.

| Файл | Уровень | Claude | Codex | Усилие |
|---|---|---|---|---|
| ../AGENTS.md (руководитель) | strong | opus | Astra | medium |
| 01-issledovatel | light | haiku | Terra | low |
| 02-faktcheker | mid | sonnet | Sol | medium |
| 03-avtor (×3) | mid | sonnet | Sol | high |
| 04-redaktor | strong | opus | Astra | high |
| 05-antislop | mid | sonnet | Sol | medium |
| 06-vypuskayushchiy | light | haiku | Terra | low |

Почему именно так: `../instrumenty/modeli-i-usilie.md`.

`mcp__perplexity`, `mcp__firecrawl`, `mcp__ahrefs` в списке инструментов работают, только если эти MCP подключены (`../instrumenty/mcp.md`). Без них агент просто ими не пользуется.
