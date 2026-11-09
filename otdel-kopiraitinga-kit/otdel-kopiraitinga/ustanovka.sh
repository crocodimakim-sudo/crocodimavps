#!/usr/bin/env bash
# Установка отдела копирайтинга. Запускать из папки otdel-kopiraitinga.
#   bash ustanovka.sh           — для Claude Code и Codex сразу
#   bash ustanovka.sh claude    — только Claude Code
#   bash ustanovka.sh codex     — только Codex
set -e
cd "$(dirname "$0")"
P=${1:-oba}
want() { [ "$P" = oba ] || [ "$P" = "$1" ]; }

echo "▶ Агенты из agents/*.md + instrumenty/modeli.conf"
bash sobrat-agentov.sh
want claude || rm -rf .claude/agents
want codex  || rm -rf .codex

DIRS=(); want claude && DIRS+=(.claude/skills); want codex && DIRS+=(.agents/skills)
echo "▶ Свои скилы → ${DIRS[*]}"
for d in "${DIRS[@]}"; do mkdir -p "$d"; cp -r instrumenty/skills/* "$d/"; done

echo "▶ Внешние скилы (по карте instrumenty/karta-skilov.md)"
AG=(); want claude && AG+=(claude-code); want codex && AG+=(codex)
if command -v npx >/dev/null; then
  for a in "${AG[@]}"; do
    for s in copywriting copy-editing; do
      npx -y skills add coreyhaines31/marketingskills --skill $s --agent $a -y || echo "  ! $s для $a не поставился, см. instrumenty/skills.md"
    done
  done
else
  echo "  ! нет npx (Node.js). Установите Node.js и запустите скрипт снова"
fi
for d in "${DIRS[@]}"; do
  [ -d "$d/humanizer" ] || git clone -q --depth 1 https://github.com/blader/humanizer "$d/humanizer" || echo "  ! humanizer в $d не поставился"
done

echo "▶ Программы для транскрипции"
for t in yt-dlp ffmpeg; do command -v $t >/dev/null && echo "  ✓ $t" || echo "  ✗ $t — установить (brew install $t / pip install $t)"; done
# 2026-11-09: python3 нужен для скриптов замера текста (instrumenty/skripty/)
command -v python3 >/dev/null && echo "  ✓ python3" || echo "  ✗ python3 — установить (нужен для clean_text.py и detect_ai.py)"
python3 -c "import faster_whisper" 2>/dev/null && echo "  ✓ faster-whisper" || echo "  ✗ faster-whisper — pip install faster-whisper"

echo
echo "▶ Осталось вручную: MCP с вашими ключами (в файлы ключи не пишем)"
if want claude; then cat <<'TXT'
  Claude Code:
    claude mcp add perplexity --env PERPLEXITY_API_KEY="КЛЮЧ" -- npx -y @perplexity-ai/mcp-server
    claude mcp add youtube-transcript -- uvx --from git+https://github.com/jkawamoto/mcp-youtube-transcript mcp-youtube-transcript
TXT
fi
if want codex; then cat <<'TXT'
  Codex:
    codex mcp add perplexity --env PERPLEXITY_API_KEY="КЛЮЧ" -- npx -y @perplexity-ai/mcp-server
    codex mcp add youtube-transcript -- uvx --from git+https://github.com/jkawamoto/mcp-youtube-transcript mcp-youtube-transcript
    Проверьте ID моделей: запустите codex, введите /model и при необходимости поправьте instrumenty/modeli.conf
TXT
fi
echo "  (по желанию) Firecrawl и Ahrefs — instrumenty/mcp.md"
echo
echo "▶ Готово. Запустите claude или codex в этой папке и напишите «Привет» — руководитель отдела начнёт интервью."
