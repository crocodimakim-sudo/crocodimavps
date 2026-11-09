#!/usr/bin/env bash
# Установка отдела копирайтинга для Claude Code. Запускать из папки otdel-kopiraitinga.
set -e
cd "$(dirname "$0")"
echo "▶ Агенты → .claude/agents/"
mkdir -p .claude/agents .claude/skills
cp agents/0*.md .claude/agents/

echo "▶ Свои скилы → .claude/skills/"
cp -r instrumenty/skills/* .claude/skills/

echo "▶ Внешние скилы (по карте instrumenty/karta-skilov.md)"
if command -v npx >/dev/null; then
  npx -y skills add coreyhaines31/marketingskills --skill copywriting --agent claude-code || echo "  ! copywriting не поставился, см. instrumenty/skills.md"
  npx -y skills add coreyhaines31/marketingskills --skill copy-editing --agent claude-code || echo "  ! copy-editing не поставился"
else
  echo "  ! нет npx (Node.js). Установите Node.js и запустите скрипт снова"
fi
if [ ! -d .claude/skills/humanizer ]; then
  git clone --depth 1 https://github.com/blader/humanizer .claude/skills/humanizer || echo "  ! humanizer не поставился"
fi

echo "▶ Проверка программ для транскрипции"
for t in yt-dlp ffmpeg; do command -v $t >/dev/null && echo "  ✓ $t" || echo "  ✗ $t — установить (brew install $t / pip install $t)"; done
python3 -c "import faster_whisper" 2>/dev/null && echo "  ✓ faster-whisper" || echo "  ✗ faster-whisper — pip install faster-whisper"

cat <<'TXT'

▶ Осталось вручную (нужны ваши ключи, в файлы их не пишем):
  claude mcp add perplexity --env PERPLEXITY_API_KEY="КЛЮЧ" -- npx -y @perplexity-ai/mcp-server
  claude mcp add youtube-transcript -- uvx --from git+https://github.com/jkawamoto/mcp-youtube-transcript mcp-youtube-transcript
  (по желанию) Firecrawl и Ahrefs — см. instrumenty/mcp.md

▶ Готово. Запустите: claude   и напишите «Привет» — руководитель отдела начнёт интервью.
TXT
