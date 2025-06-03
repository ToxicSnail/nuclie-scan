#!/usr/bin/env python3
"""
aggregate_urls.py

Собирает все URL из файлов test*.txt в каталоге reports/<TIMESTAMP>/raw,
убирает ANSI-коды и формирует итоговый файл по заданному шаблону:
  — без флагов: только URL
  — с --include-codes: URL [код1 код2 …]

Если аргумент --raw-path передан (и не пуст), используется он; иначе
автоматически находим последний каталог в reports/ и берём его подпапку raw/.
"""

import re
import sys
import argparse
from pathlib import Path
from collections import defaultdict

# ─────────────────────────── ПАРАМЕТРЫ ────────────────────────────────

# Регулярка для удаления ANSI escape sequences (цветовых кодов)
ANSI_ESCAPE_RE = re.compile(r'\x1B\[[0-?]*[ -/]*[@-~]')


def strip_ansi(line: str) -> str:
    """Удаляет ANSI-последовательности из строки."""
    return ANSI_ESCAPE_RE.sub("", line)


def collect_raw_dir() -> Path:
    """
    Автоматически находит самый «свежий» (по имени) каталог внутри reports/,
    затем возвращает его подпапку raw/. Если что-то не найдено — выходит с ошибкой.
    """
    base = Path("reports")
    if not base.is_dir():
        print(f"[ERROR] Папка 'reports' не найдена рядом со скриптом.", file=sys.stderr)
        sys.exit(1)

    # Находим все директории-таймштампы
    timestamps = [d for d in base.iterdir() if d.is_dir()]
    if not timestamps:
        print(f"[ERROR] В папке 'reports' нет подкаталогов.", file=sys.stderr)
        sys.exit(1)

    # Сортируем лексикографически по имени (формат YYYY-MM-DD_HH-MM-SS)
    latest_ts = sorted(timestamps, key=lambda p: p.name, reverse=True)[0]
    raw_dir = latest_ts / "raw"
    if not raw_dir.is_dir():
        print(f"[ERROR] Подпапка 'raw' не найдена в '{latest_ts.name}'.", file=sys.stderr)
        sys.exit(1)

    return raw_dir


def parse_args():
    p = argparse.ArgumentParser(
        description="Собирает URL из test*.txt в reports/<TIMESTAMP>/raw и формирует итоговый файл."
    )
    p.add_argument(
        "--include-codes", "-c", action="store_true",
        help="Включить status-коды рядом с URL (например: 'https://foo.com/ [200]')."
    )
    p.add_argument(
        "--raw-path", "-r", metavar="DIR", default="",
        help="Явно указать путь к папке raw вместо автоматического поиска."
    )
    p.add_argument(
        "--output", "-o", metavar="FILE", default="all_urls_sorted.txt",
        help="Имя итогового файла (по умолчанию: %(default)s). Сохранится рядом с reports/<TIMESTAMP>."
    )
    return p.parse_args()


def main():
    args = parse_args()

    # 1) Определяем каталог raw:
    if args.raw_path:
        raw_dir = Path(args.raw_path)
        if not raw_dir.is_dir():
            print(f"[ERROR] Указанная папка '{raw_dir}' не существует или не является директорией.", file=sys.stderr)
            sys.exit(1)
    else:
        raw_dir = collect_raw_dir()

    print(f"[INFO] Используем raw-каталог: {raw_dir}")

    # 2) Сбор URL (и кода при необходимости)
    if args.include_codes:
        url_to_codes = defaultdict(set)
    else:
        urls = set()

    for filepath in sorted(raw_dir.iterdir()):
        if not filepath.is_file():
            continue
        if not (filepath.name.startswith("test") and filepath.name.endswith(".txt")):
            continue

        with filepath.open("r", encoding="utf-8", errors="ignore") as f:
            for raw_line in f:
                line = strip_ansi(raw_line).strip()
                if not line:
                    continue

                # Случай: хотим сохранить коды
                if args.include_codes:
                    parts = line.split(": ", 1)
                    if len(parts) != 2:
                        continue
                    url, code = parts
                    if url.startswith("http://") or url.startswith("https://"):
                        url_to_codes[url].add(code)
                else:
                    # Без кодов: просто берём часть до ": " или всю строку
                    parts = line.split(": ", 1)
                    url = parts[0]
                    if url.startswith("http://") or url.startswith("https://"):
                        urls.add(url)

    # 3) Формируем итоговый файл
    parent_ts = raw_dir.parent  # reports/<TIMESTAMP>
    output_path = parent_ts / args.output

    if args.include_codes:
        if not url_to_codes:
            print("[WARN] Не найдено ни одного URL с кодами.", file=sys.stderr)
            sys.exit(0)

        with output_path.open("w", encoding="utf-8") as out:
            for url in sorted(url_to_codes):
                codes = sorted(
                    url_to_codes[url],
                    key=lambda x: int(x) if x.isdigit() else x
                )
                codes_str = " ".join(codes)
                out.write(f"{url} [{codes_str}]\n")
    else:
        if not urls:
            print("[WARN] Не найдено ни одного URL.", file=sys.stderr)
            sys.exit(0)

        with output_path.open("w", encoding="utf-8") as out:
            for url in sorted(urls):
                out.write(url + "\n")

    print(f"[OK] Итоговый файл сохранён: {output_path}")


if __name__ == "__main__":
    main()
