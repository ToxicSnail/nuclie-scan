set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

QUIET=0

info() {
    echo -e "${YELLOW}[INFO]  $*${NC}"
}
succ() {
    echo -e "${GREEN}[OK]    $*${NC}"
}
warn() {
    echo -e "${RED}[WARN]  $*${NC}"
}
err() {
  echo -e "${RED}[ERROR] $*${NC}" >&2
  exit 1
}

SCAN_SCRIPT="./httpx_scanner.sh"
AGGREGATOR_SCRIPT="./aggregator.py"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [command] [options]

Commands:
  scan         Запустить сканирование через httpx
  aggregate    Агрегировать результаты сканирования
  help         Показать это сообщение

Options (для scan):
  -i <file>    Указать файл со списком сайтов (по умолчанию sites_to_scan.txt)
  -t "<opts>"  Параметры для httpx в кавычках (например: '-status-code -title')
  -n <number>  Количество прогонов сканирования (по умолчанию 5)
  -q           Минимальный вывод (quiet mode)

Примеры:
  $0 scan -i my_sites.txt -t "-status-code -title" -n 10 -q
  $0 aggregate
EOF
}

main() {
  if [[ $# -lt 1 ]]; then
    warn "No command."
    show_help
    exit 1
  fi

  COMMAND="$1"
  shift

  INPUT_FILE=""
  HTTPX_OPTS=""

  while getopts "i:t:n:qh" opt; do
    case $opt in
      i)
        INPUT_FILE="$OPTARG"
        ;;
      t)
        HTTPX_OPTS="$OPTARG"
        ;;
      n)
        SCAN_TIMES="$OPTARG"
        ;;
      q)
        QUIET=1
        ;;
      h)
        show_help
        exit 0
        ;;
      \?)
        err "Unknown parameter: -$OPTARG"
        ;;
    esac
  done
  shift $((OPTIND-1))

  case "$COMMAND" in
    scan)
      info "Start a scan..."
      ENV_VARS=""
      if [[ -n "$INPUT_FILE" ]]; then
        info "The sites file will be used: $INPUT_FILE"
        ENV_VARS+="INPUT_FILE=\"$INPUT_FILE\" "
      fi
      if [[ -n "$HTTPX_OPTS" ]]; then
        info "Parameters for httpx: $HTTPX_OPTS"
        ENV_VARS+="HTTPX_OPTS=\"$HTTPX_OPTS\" "
      fi
      if [[ -n "$SCAN_TIMES" ]]; then
        info "Number of runs: $SCAN_TIMES"
        ENV_VARS+="SCAN_TIMES=\"$SCAN_TIMES\" "
      fi
      ENV_VARS+="QUIET=$QUIET "
      eval "$ENV_VARS bash \"$SCAN_SCRIPT\""
      ;;
    aggregate)
      info "Start aggregation..."
      python3 "$AGGREGATOR_SCRIPT"
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      err "Unknown command: $COMMAND"
      show_help
      ;;
  esac
}

main "$@"
