#!/usr/bin/env bash
# Собирает файлы агентов для Claude Code и Codex из ОДНОГО источника: agents/*.md + instrumenty/modeli.conf
# Запускать после любой правки роли или модели. Руками .claude/agents и .codex/agents не править.
set -e
cd "$(dirname "$0")"
source instrumenty/modeli.conf
mkdir -p .claude/agents .codex/agents

field() { awk -v k="$1" 'NR>1 && /^---$/ {exit} NR>1 { if (index($0, k": ")==1) { sub("^"k": ", ""); print } }' "$2"; }
body()  { awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n>=2 {print}' "$1"; }

for f in agents/0*.md; do
  name=$(field name "$f"); desc=$(field description "$f")
  lvl=$(field uroven "$f"); eff=$(field usilie "$f"); tools=$(field claude_tools "$f")
  case "$lvl" in
    light)  cm=$CLAUDE_LIGHT;  xm=$CODEX_LIGHT ;;
    mid)    cm=$CLAUDE_MID;    xm=$CODEX_MID ;;
    strong) cm=$CLAUDE_STRONG; xm=$CODEX_STRONG ;;
    *) echo "  ! $f: неизвестный uroven '$lvl'"; exit 1 ;;
  esac

  # Claude Code
  { echo "---"; echo "name: $name"; echo "description: $desc"; echo "model: $cm"; echo "effort: $eff"; echo "tools: $tools"; echo "---"; body "$f"; } > ".claude/agents/$name.md"

  # Codex (инструментов-allowlist у Codex нет, поэтому список идёт текстом в инструкцию)
  if body "$f" | grep -q "'''"; then echo "  ! $f содержит ''' — уберите, это ломает TOML"; exit 1; fi
  {
    echo "# Сгенерировано из $f скриптом sobrat-agentov.sh. Не править руками."
    echo "name = \"$name\""
    echo "description = \"${desc//\"/\\\"}\""
    echo "model = \"$xm\""
    echo "model_reasoning_effort = \"$eff\""
    echo "developer_instructions = '''"
    echo "Допустимые инструменты (остальными не пользуйся): $tools. Названия даны в терминах Claude Code — используй их аналоги в Codex."
    echo "Правила по инструментам: instrumenty/dopustimye-instrumenty.md"
    echo
    body "$f"
    echo "'''"
  } > ".codex/agents/$name.toml"
  echo "  ✓ $name: Claude=$cm/$eff, Codex=$xm/$eff"
done

# Главная сессия (руководитель отдела) для Codex: сильная модель, усилие medium
cat > .codex/config.toml <<TOML
# Сгенерировано sobrat-agentov.sh. Проектные настройки Codex для отдела копирайтинга.
# Руководитель отдела = главная сессия.
model = "$CODEX_STRONG"
model_reasoning_effort = "medium"

[agents]
max_threads = 4   # трём авторам нужно работать параллельно

# Если ваша версия Codex требует явно включить субагентов, раскомментируйте:
# [features]
# multi_agent = true
TOML
echo "  ✓ .codex/config.toml: руководитель = $CODEX_STRONG / medium"
