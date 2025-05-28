# HTTPX-Only Endscaner Script

**Branch:** `future/httpx`

Скрипт `endscaner.sh` предназначен для быстрого сканирования списка URL с помощью `httpx` и гибкой фильтрации по HTTP-кодам. Все результаты сохраняются в папке `reports/<timestamp>/`.

---

## Основные возможности

- **Проверка зависимостей**: `httpx`, `jq`.
- **Сканирование статусов** всех URL из `sites_to_scan.txt`.
- **Гибкая фильтрация**:
  - **Whitelist**: вывод только URL с кодами из белого списка.
  - **Blacklist**: вывод всех URL **кроме** тех, чьи коды указаны в чёрном списке.
  - Если оба списка пусты — выводятся все URL.
- **Сохранение**:
  - Сырые JSON-данные из `httpx` → `reports/<TS>/httpx_<TS>.json`
  - Окончательный список URL → `reports/<TS>/live_sites_<TS>.txt`

---

## Настройка

1. **Скрипт**: `endscaner.sh` в корне репозитория.
2. **Список URL**: файл `sites_to_scan.txt` — по одному URL в строке (с `http://` и(или) `https://`).
3. **Переменные в начале `endscaner.sh`**:
   ```bash
   INPUT_FILE="sites_to_scan.txt"        # входной файл URL
   HTTPX_OPTS_DEFAULT=(-silent -follow-redirects -json -status-code)

   # Поля JSON для фильтрации
   PARSE_FIELD_DEFAULT="url"
   JSON_FIELD_STATUS="status_code"

   # Белый список (whitelist)
   WHITELIST_CODES_DEFAULT=(200 301)

   # Чёрный список (blacklist)
   BLACKLIST_CODES_DEFAULT=(404 500)
   ```
   - `WHITELIST_CODES_DEFAULT`: если не пуст, скрипт выведет *только* URL с этими кодами.
   - `BLACKLIST_CODES_DEFAULT`: если `WHITELIST_CODES_DEFAULT` пуст, но `BLACKLIST_CODES_DEFAULT` не пуст, выведутся **все URL, кроме** указанных кодов.
   - Если оба массива пусты — выводятся все URL.

---

## Установка зависимостей

```bash
sudo apt update
sudo apt install -y httpx jq
```

*Для `httpx` используйте CLI-версию ProjectDiscovery, а не Python-библиотеку.*

---

## Запуск

```bash
chmod +x endscaner.sh
./endscaner.sh
```

### Примеры

- **Только 200 OK и 301** (whitelist):
  ```bash
  # В endscaner.sh: 
  # WHITELIST_CODES_DEFAULT=(200 301)
  ./endscaner.sh
  ```

- **Все, кроме 404 и 500** (blacklist):
  ```bash
  # В endscaner.sh: 
  # WHITELIST_CODES_DEFAULT=()
  # BLACKLIST_CODES_DEFAULT=(404 500)
  ./endscaner.sh
  ```

- **Все статусы (без фильтрации)**:
  ```bash
  # Оставить оба списка пустыми
  ./endscaner.sh
  ```

---

После выполнения результаты окажутся в папке:

```
reports/2025-05-27_12-34-56/
├── httpx_2025-05-27_12-34-56.json   # полный JSON-ответ httpx
└── live_sites_2025-05-27_12-34-56.txt  # отфильтрованный список URL
```

---

*Конфигурация скрипта находится в начале файла `endscaner.sh` — просто правьте массивы whitelist/blacklist и опции `httpx` под свои задачи.*
