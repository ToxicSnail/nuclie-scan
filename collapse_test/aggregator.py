import os
import re
import sys

from pathlib import Path

QUIET = os.getenv("QUIET", "0") == "1"
RAW_DIR = None  # для скана последней папки
# RAW_DIR = Path("reports/2025-06-03_23-04-25/raw") # Для скана опред папки

OUTPUT_FILE = "all_urls_sorted.txt"

ANSI_ESCAPE_RE = re.compile(r'\x1B\[[0-?]*[ -/]*[@-~]')

def strip_ansi(line: str) -> str:
    return ANSI_ESCAPE_RE.sub("", line)

def collect_raw_dir() -> Path:
    base = Path("reports")
    if not base.exists() or not base.is_dir():
        print(f"[ERROR] Папка {base!r} не найдена.", file=sys.stderr)
        sys.exit(1)

    timestamps = [d for d in base.iterdir() if d.is_dir()]
    if not timestamps:
        print(f"[ERROR] В {base!r} нет подкаталогов.", file=sys.stderr)
        sys.exit(1)

    timestamps_sorted = sorted(timestamps, key=lambda p: p.name, reverse=True)
    latest_dir = timestamps_sorted[0]
    raw_dir = latest_dir / "raw"
    if not raw_dir.exists() or not raw_dir.is_dir():
        print(f"[ERROR] Папка {raw_dir!r} не найдена.", file=sys.stderr)
        sys.exit(1)

    return raw_dir

def main():
    if RAW_DIR is not None:
        raw_dir = Path(RAW_DIR)
        if not raw_dir.exists() or not raw_dir.is_dir():
            print(f"[ERROR] Указанная папка {raw_dir!r} не найдена или не является директорией.", file=sys.stderr)
            sys.exit(1)
        print(f"[INFO] Используем указанную папку: {raw_dir}")
    else:
        raw_dir = collect_raw_dir()
        print(f"[INFO] Используем автоматически найденную папку: {raw_dir}")

    urls = set()
    for path in sorted(raw_dir.iterdir()):
        if not path.is_file():
            continue
        if not (path.name.startswith("test") and path.name.endswith(".txt")):
            continue

        with path.open("r", encoding="utf-8", errors="ignore") as f:
            for raw_line in f:
                line = strip_ansi(raw_line).strip()
                if line.startswith("http://") or line.startswith("https://"):
                    urls.add(line)

    if not urls:
        print("[WARN] Не найдено ни одного URL.", file=sys.stderr)
        sys.exit(0)

    sorted_urls = sorted(urls)

    output_path = raw_dir.parent / OUTPUT_FILE
    with output_path.open("w", encoding="utf-8") as out:
        for url in sorted_urls:
            out.write(url + "\n")

    print(f"[OK] Итоговый файл создан: {output_path}")

if __name__ == "__main__":
    main()
