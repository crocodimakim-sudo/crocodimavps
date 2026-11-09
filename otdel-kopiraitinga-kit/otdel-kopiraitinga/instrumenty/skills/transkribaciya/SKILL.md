---
name: transkribaciya
description: Делает текстовую расшифровку видео и аудио из YouTube, Instagram (Reels, посты), подкастов и голосовых, чтобы их можно было читать и цитировать. Использовать, когда в брифе или материалах есть ссылка на видео/аудио или медиафайл.
---

# Транскрипция YouTube / Instagram / аудио

## Шаг 1. Есть ли готовые субтитры?
- **YouTube:** сначала MCP `youtube-transcript` (быстро, без скачивания). Если субтитров нет — шаг 2.
- **Instagram, подкасты, файлы:** сразу шаг 2.

## Шаг 2. Скачать только аудио
```bash
mkdir -p /tmp/transkr && cd /tmp/transkr
yt-dlp -x --audio-format mp3 -o "%(id)s.%(ext)s" "ССЫЛКА"
```
- Instagram часто требует вход: `yt-dlp --cookies-from-browser chrome -x --audio-format mp3 "ССЫЛКА"`.
- Скачивать только то, на что у владельца есть право использовать для работы (свой контент, публичное для цитирования с указанием автора).

## Шаг 3. Расшифровать (локально, бесплатно)
```bash
# один раз: pip install faster-whisper
python3 - <<'PY'
from faster_whisper import WhisperModel
import glob
m = WhisperModel("small", compute_type="int8")   # medium/large-v3 точнее, но медленнее
for f in glob.glob("/tmp/transkr/*.mp3"):
    segs, _ = m.transcribe(f, language="ru")
    open(f[:-4] + ".txt", "w").write("\n".join(f"[{s.start:06.1f}] {s.text.strip()}" for s in segs))
PY
```
Альтернатива без установки: загрузить файл в любой сервис расшифровки, которым владелец уже пользуется, и положить текст в `import/transkripty/`.

## Шаг 4. Оформить
Файл `import/transkripty/NNNN_istochnik_tema.md`:
```
---
источник: [ссылка]
автор: [канал / аккаунт]
дата_видео: [ГГГГ-ММ-ДД]
длительность: [мм:сс]
---
## Краткое содержание (5 пунктов)
## Цитаты, пригодные для текста (с таймкодом)
## Полная расшифровка
```
Убрать слова-паразиты в цитатах можно, менять смысл нельзя.

## Требования
`yt-dlp`, `ffmpeg`, `faster-whisper` (Python). `ustanovka.sh` проверяет их наличие.
