#!/usr/bin/env python3
# 2026-11-02: очистка текста от невидимых символов (нулевая ширина, мягкий перенос, bidi, теги)
# без порчи русской типографики. Только стандартная библиотека, без сети.
"""Очистка .txt/.md от невидимых символов.

Удаляет: U+200B-200F, U+2060-2064, U+FEFF, U+00AD, U+180E, теги U+E0000-E007F,
bidi U+202A-202E и прочие символы категории Cf.
НЕ трогает: длинное и короткое тире, «ёлочки», „лапки“, многоточие, U+00A0 и U+202F.
Флаг --nbsp-to-space заменяет эти два неразрывных пробела обычным пробелом (только по просьбе).

Это локальная очистка, а не гарантия «незаметности» для каких-либо детекторов.

Примеры:
  python -X utf8 clean_text.py текст.md -o чистый.md --report
  python -X utf8 clean_text.py текст.md --check
  type текст.txt | python -X utf8 clean_text.py -
"""
import argparse
import re
import sys
import unicodedata
from collections import Counter

# Явный список (всё это и так Cf, кроме 180E в старых версиях Unicode — держим явно)
_ЯВНЫЕ = set()
for _a, _b in ((0x200B, 0x200F), (0x2060, 0x2064), (0x202A, 0x202E), (0xE0000, 0xE007F)):
    _ЯВНЫЕ.update(range(_a, _b + 1))
_ЯВНЫЕ.update({0xFEFF, 0x00AD, 0x180E})

# Неразрывные пробелы: нормальная русская типографика, по умолчанию не трогаем
НЕРАЗРЫВНЫЕ = {" ", " "}


def невидимый(ch):
    """True, если символ невидимый и подлежит удалению."""
    if ch in НЕРАЗРЫВНЫЕ:
        return False
    cp = ord(ch)
    return cp in _ЯВНЫЕ or unicodedata.category(ch) == "Cf"


def найти_невидимые(text):
    """Counter {символ: сколько раз}."""
    return Counter(ch for ch in text if невидимый(ch))


def очистить(text, nbsp_to_space=False):
    """Возвращает (чистый_текст, Counter удалённого)."""
    удалено = Counter()
    out = []
    for ch in text:
        if невидимый(ch):
            удалено[ch] += 1
            continue
        if nbsp_to_space and ch in НЕРАЗРЫВНЫЕ:
            удалено[ch] += 1
            out.append(" ")
            continue
        out.append(ch)
    return "".join(out), удалено


def _имя(ch):
    try:
        return unicodedata.name(ch)
    except ValueError:
        return "(без имени)"


def таблица(счётчик):
    строки = ["символ    код      сколько  название"]
    for ch, n in sorted(счётчик.items(), key=lambda kv: ord(kv[0])):
        строки.append("%-9s U+%04X   %-7d  %s" % ("(скрыт)" if невидимый(ch) else repr(ch), ord(ch), n, _имя(ch)))
    return "\n".join(строки)


def main(argv=None):
    p = argparse.ArgumentParser(
        description="Очистка невидимых символов в .txt/.md (локально, без сети; не гарантия обхода детекторов).",
        epilog="Код выхода: 0 — всё в порядке; 1 — с --check нашлись невидимые символы; 2 — ошибка ввода.",
    )
    p.add_argument("вход", help="файл .txt/.md или - (stdin)")
    p.add_argument("-o", "--output", help="файл результата (по умолчанию stdout)")
    p.add_argument("--report", action="store_true", help="таблица найденного в stderr")
    p.add_argument("--check", action="store_true", help="ничего не менять; код выхода 1, если есть невидимые символы")
    p.add_argument("--nbsp-to-space", action="store_true", help="заменить U+00A0 и U+202F обычным пробелом")
    a = p.parse_args(argv)

    for s in (sys.stdout, sys.stderr):
        try:
            s.reconfigure(encoding="utf-8")
        except Exception:
            pass

    if a.вход == "-":
        text = sys.stdin.buffer.read().decode("utf-8", errors="replace")
    else:
        if a.вход.lower().endswith(".docx"):
            print("Формат .docx не поддерживается: сохрани текст как .txt или .md.", file=sys.stderr)
            return 2
        try:
            with open(a.вход, "rb") as f:
                text = f.read().decode("utf-8", errors="replace")
        except OSError as e:
            print("Не удалось прочитать файл: %s" % e, file=sys.stderr)
            return 2

    if a.check:
        найдено = найти_невидимые(text)
        if a.report or найдено:
            print(таблица(найдено) if найдено else "Невидимых символов нет.", file=sys.stderr)
        # 2026-11-02: правило {{цифра}} (pravila-proekta/03-stop-slova-neyroslop.md) — текст с меткой наружу не уходит
        метки = re.findall(r"\{\{[^{}]*\}\}", text)
        for м in метки:
            print("МЕТКА не заменена: %s" % м, file=sys.stderr)
        if найдено:
            print("НАЙДЕНО невидимых: %d" % sum(найдено.values()))
        if метки:
            print("НЕ ЗАМЕНЕНО меток {{…}}: %d" % len(метки))
        if not найдено and not метки:
            print("ЧИСТО")
        return 1 if (найдено or метки) else 0

    чистый, удалено = очистить(text, a.nbsp_to_space)
    if a.report:
        print(таблица(удалено) if удалено else "Удалять нечего.", file=sys.stderr)
        print("Всего изменено: %d" % sum(удалено.values()), file=sys.stderr)
    data = чистый.encode("utf-8")
    if a.output:
        with open(a.output, "wb") as f:
            f.write(data)
    else:
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
