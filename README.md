# Руководство по использованию `endscaner.sh`

## Назначение

`endscaner.sh` — это простой Bash-скрипт, автоматизирующий две самые популярные операции:
1. **Проверку доступности списка сайтов** с помощью [httpx](https://github.com/projectdiscovery/httpx) и фильтрацию по HTTP-кодам.
2. **Запуск сканирования** найденных «живых» URL на уязвимости с помощью [nuclei](https://github.com/projectdiscovery/nuclei).

Все артефакты (JSON-ответы, списки живых URL, результаты nuclei и логи) автоматически сохраняются в папке:
```
reports/<ГГГГ‐ММ‐ДД_ЧЧ‐ММ‐СС>/
```

## Требования

- Linux / macOS с Bash / WSL 
- Установленные утилиты:
  - `httpx` (ProjectDiscovery CLI-версия, не Python-библиотека)  
  - `jq` (для разбора JSON)  
  - `nuclei` (CLI сканер шаблонов)  

Проверить наличие:
```bash
command -v httpx jq nuclei
```

## Установка скрипта
1. Скопируйте содержимое в файл scan.sh:
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
