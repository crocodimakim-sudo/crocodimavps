# Скилы: что ставить, в каком порядке и когда запускать

Скил — папка с `SKILL.md`, которую Claude подхватывает сам, когда задача подходит. Ставятся в `~/.claude/skills/` (для всех проектов) или `.claude/skills/` (только для этого отдела).

> Перед установкой любого скила с GitHub откройте его `SKILL.md` и прочитайте. Это инструкция для вашего агента: ставьте только то, что понимаете.

## Обязательные

| # | Скил | Откуда | Зачем | Когда запускается |
|---|---|---|---|---|
| 0 | **intervyu-brif** | свой, `instrumenty/skills/intervyu-brif/` | Мини-интервью перед каждым текстом (адаптация [grill-me](https://github.com/mattpocock/skills) Мэтта Покока под копирайтинг) | Шаг 0, всегда |
| 1 | **copywriting** | [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) | Фреймворки маркетинговых текстов, заголовки, CTA | Шаг 3: авторы при письме |
| 2 | **humanizer** | [blader/humanizer](https://github.com/blader/humanizer) | Убирает признаки ИИ-письма. Основан на гайде Википедии [Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) | Шаг 5, первым |
| 3 | **antislop-ru** | свой, `instrumenty/skills/antislop-ru/` | Русский нейрослоп и канцелярит | Шаг 5, вторым |
| 4 | **copy-editing** | [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) | Редактура по проходам: ясность, конкретика, доказательства | Шаг 5, третьим |
| 5 | **transkribaciya** | свой, `instrumenty/skills/transkribaciya/` | YouTube / Instagram / подкаст → текст | Шаг 1a, до исследования |

## Полезные

| Скил | Откуда | Зачем |
|---|---|---|
| остальные из marketingskills (`social-content`, `email-sequence`, `content-strategy` и др.) | coreyhaines31/marketingskills | Контент-планы, рассылки, соцсети. Посмотрите список в репозитории |
| **skill-creator** | [anthropics/skills](https://github.com/anthropics/skills) | Сделать свой скил, например «мой голос в ТГ» по вашим референсам |
| **docx / pdf** | anthropics/skills | Отдать текст клиенту в Word / PDF |

## Что берём из каждого скила
Не всё. Карта и причины: `karta-skilov.md`. Коротко: голос только из `reference-list/`, у каждой задачи один скил-хозяин.

## Порядок запуска (сводно)
```
Шаг 0   intervyu-brif                           (всегда)
Шаг 1a  transkribaciya                          (если есть видео)
Шаг 3   copywriting                             (у каждого автора)
Шаг 5   humanizer → antislop-ru → copy-editing  (строго в этом порядке)
```
**Почему такой порядок в шаге 5:** сначала ломаем ИИ-структуру текста (крупное), потом чистим слова (мелкое), потом полируем. Если полировать раньше, следующий шаг снова всё сдвинет.

## Установка
```bash
# marketingskills: copywriting и copy-editing (только в этот проект)
npx -y skills add coreyhaines31/marketingskills --skill copywriting --agent claude-code
npx -y skills add coreyhaines31/marketingskills --skill copy-editing --agent claude-code

# humanizer
git clone https://github.com/blader/humanizer .claude/skills/humanizer

# свои скилы из этого архива
cp -r instrumenty/skills/* .claude/skills/

# anthropics/skills (внутри Claude Code)
/plugin marketplace add anthropics/skills
```
Или просто `bash ustanovka.sh`.

## Ручные сервисы для русского текста (не скилы, проверять глазами)
- [Главред](https://glvrd.ru) — стоп-слова, инфостиль, оценка по 10-балльной шкале.
- [Тургенев](https://turgenev.ashmanov.com) — водность, переспам, риск фильтров Яндекса для SEO-текстов.
