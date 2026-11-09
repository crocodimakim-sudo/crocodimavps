# MCP-серверы: внешние руки отдела

MCP — способ подключить к Claude внешний сервис: поиск, транскрипты, SEO-данные.
Ключи API хранить только в настройках, никогда не вставлять в тексты и файлы проекта.

| MCP | Для чего | Кто использует | Нужен ключ | Приоритет |
|---|---|---|---|---|
| **Perplexity** | Актуальный поиск со ссылками: новости, статистика, свежие исследования | Исследователь, фактчекер | да, Perplexity API (платно, по запросам) | обязательно |
| **YouTube Transcript** | Субтитры YouTube-видео без скачивания | Исследователь | нет | обязательно |
| **Firecrawl** | Чисто вытащить текст со страницы, обойти сайт конкурента | Исследователь, фактчекер | да (есть бесплатный лимит) | желательно |
| **Ahrefs** | Ссылочная масса, доноры, DR, ключевые слова | Фактчекер (SEO) | да, подписка Ahrefs с доступом к API | для SEO |
| **Google Drive / Docs** | Брать брифы из Google Docs, отдавать тексты туда | Главред, выпускающий | вход через Google | по желанию |

## Установка
Команды почти одинаковые: `claude mcp add` для Claude Code и `codex mcp add` для Codex.
```bash
# Perplexity (официальный: github.com/perplexityai/modelcontextprotocol)
claude mcp add perplexity --env PERPLEXITY_API_KEY="ВАШ_КЛЮЧ" -- npx -y @perplexity-ai/mcp-server
codex  mcp add perplexity --env PERPLEXITY_API_KEY="ВАШ_КЛЮЧ" -- npx -y @perplexity-ai/mcp-server

# YouTube Transcript (github.com/jkawamoto/mcp-youtube-transcript)
claude mcp add youtube-transcript -- uvx --from git+https://github.com/jkawamoto/mcp-youtube-transcript mcp-youtube-transcript
codex  mcp add youtube-transcript -- uvx --from git+https://github.com/jkawamoto/mcp-youtube-transcript mcp-youtube-transcript

# Firecrawl
claude mcp add firecrawl --env FIRECRAWL_API_KEY="ВАШ_КЛЮЧ" -- npx -y firecrawl-mcp
codex  mcp add firecrawl --env FIRECRAWL_API_KEY="ВАШ_КЛЮЧ" -- npx -y firecrawl-mcp
```
Где хранится: Claude Code — в своих настройках (пример файла: `mcp.json.primer`); Codex — в `~/.codex/config.toml`, секции `[mcp_servers.<имя>]` (пример: `codex-mcp.primer.toml`).

**Ahrefs:** подключается по инструкции Ahrefs (раздел MCP / API в их документации) или как коннектор в claude.ai → Settings → Connectors.

**Без терминала** (claude.ai или ChatGPT): коннекторы подключаются в настройках приложения из их каталога. Чего нет в каталоге, работает только в Claude Code или Codex.

## Как делить поиск между Perplexity и Claude
- **Perplexity:** «что нового», «какая статистика за 2026», «кто писал об этом за последний месяц». Ему поиск — основная работа.
- **Встроенный поиск агента (WebSearch / WebFetch в Claude, web search в Codex):** открыть и прочитать конкретную ссылку, проверить, что страница существует.
- **Ahrefs:** всё про ссылки и ключевые слова. Не спрашивать это у Perplexity: он даст пересказ, а не данные.

> Названия пакетов и команды актуальны на ноябрь 2026. Если команда не сработала, откройте репозиторий по ссылке и возьмите команду из README.
