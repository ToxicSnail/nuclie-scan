#!/bin/bash


INPUT_FILE="sites_to_scan.txt"          # Файл с сайтами
LIVE_SITES="live_sites.txt"     # Файл для живых сайтов
JSON_FORMAT="json_sites.json"
LIVE200="live_sites_200.txt" # Файл для живых сайтов with status code [200]
OUTPUT_FILE="res.txt"    # Файл для результатов Nuclei
LOG_FILE="scan_log.txt"         # Лог-файл для отслеживания процесса
RATE_LIMIT=100
BULK_SIZE=50

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

check_dependencies() {
    echo -e "${YELLOW}[INFO] Проверка зависимостей...${NC}"
    if ! command -v nuclei &> /dev/null; then
        echo -e "${RED}[ERROR] Nuclei не установлен. Установите его: https://nuclei.projectdiscovery.io/${NC}"
        exit 1
    fi
    if ! command -v httpx &> /dev/null; then
        echo -e "${RED}[ERROR] HTTPX не установлен. Установите его: https://github.com/projectdiscovery/httpx${NC}"
        exit 1
    fi
    echo -e "${GREEN}[SUCCESS] Все зависимости установлены.${NC}"
}

check_live_sites() {
    echo -e "${YELLOW}[INFO] Проверка доступности сайтов из файла: $INPUT_FILE${NC}"
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo -e "${RED}[ERROR] Файл $INPUT_FILE не найден.${NC}"
        exit 1
    fi
    # cat "$INPUT_FILE" | /home/kali_gorkij/go/bin/httpx -silent -> "$LIVE_SITES"
    # cat "$INPUT_FILE" | /home/kali_gorkij/go/bin/httpx -status-code -> "$LIVE_SITES"
    # cat "$INPUT_FILE" | /home/kali_gorkij/go/bin/httpx -status-code -follow-redirects -j -> "$LIVE_SITES"
    cat "$INPUT_FILE" | httpx -j -> "$JSON_FORMAT"
    # cat "$INPUT_FILE" | /home/kali_gorkij/go/bin/httpx -mc 200 -> "$LIVE200"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] Произошла ошибка при проверке сайтов.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[SUCCESS] Живые сайты сохранены в файл: $LIVE_SITES${NC}"
}

run_nuclei_scan() {
    echo -e "${YELLOW}[INFO] Запуск сканирования Nuclei для живых сайтов...${NC}"
    if [[ ! -f "$LIVE_SITES" ]]; then
        echo -e "${RED}[ERROR] Файл $LIVE_SITES не найден. Сначала проверьте доступность сайтов.${NC}"
        exit 1
    fi
    nuclei -l "$LIVE_SITES" -follow-redirects -rate-limit "$RATE_LIMIT" -bulk-size "$BULK_SIZE" -o "$OUTPUT_FILE" 2>>"$LOG_FILE"
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[SUCCESS] Сканирование завершено. Результаты сохранены в файл: $OUTPUT_FILE${NC}"
    else
        echo -e "${RED}[ERROR] Произошла ошибка при сканировании. Проверьте логи: $LOG_FILE${NC}"
        exit 1
    fi
}

main() {
    check_dependencies
    check_live_sites
    # run_nuclei_scan
}

main


#  сервер возвращает перенаправление (например, 302 Found), HTTPX автоматически следует этому редиректу и возвращает финальный URL после всех перенаправлений.
