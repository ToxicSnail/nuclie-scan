set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

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

INPUT_FILE="${INPUT_FILE:-sites_to_scan.txt}"
OUTPUT_PREFIX="test"
STATS_FILE="stats.txt"
SCAN_TIMES="${SCAN_TIMES:-5}"
HTTPX_BIN="${HTTPX_BIN:-httpx}"
HTTPX_OPTS_STR="${HTTPX_OPTS:--status-code -silent}"
HTTPX_OPTS=($HTTPX_OPTS_STR)

TS=$(date +"%Y-%m-%d_%H-%M-%S")
BASE_DIR="reports/${TS}"
RAW_DIR="${BASE_DIR}/raw"
mkdir -p "$RAW_DIR"
STATS_PATH="${BASE_DIR}/${STATS_FILE}"

check_deps() {
  info "Checking for httpx..."
  command -v "$HTTPX_BIN" >/dev/null 2>&1 || err "'$HTTPX_BIN' not found. Install httpx CLI."
  info "Results will be saved to: $BASE_DIR"
}

run_scans() {
  >"$STATS_PATH" 
  for i in $(seq 1 "$SCAN_TIMES"); do
    output_file="${RAW_DIR}/${OUTPUT_PREFIX}${i}.txt"
    info "Run #$i: $HTTPX_BIN -l $INPUT_FILE ${HTTPX_OPTS[*]} -o $output_file"
    if [[ "$QUIET" -eq 1 ]]; then
      if ! "$HTTPX_BIN" -l "$INPUT_FILE" "${HTTPX_OPTS[@]}" -o "$output_file" > /dev/null 2>&1; then
        warn "httpx run #$i failed; continuing..."
      fi
    else
      if ! "$HTTPX_BIN" -l "$INPUT_FILE" "${HTTPX_OPTS[@]}" -o "$output_file"; then
        warn "httpx run #$i failed; continuing..."
      fi
    fi
  done
}

aggregate_results() {
  declare -A counts=()
  for i in $(seq 1 "$SCAN_TIMES"); do
    output_file="${RAW_DIR}/${OUTPUT_PREFIX}${i}.txt"
    if [[ ! -f "$output_file" ]]; then
      warn "File '$output_file' not found; skipping."
      continue
    fi
    while IFS= read -r url; do
      [[ -z "$url" ]] && continue
      counts["$url"]=$((counts["$url"] + 1))
    done <"$output_file"
  done
  {
    echo "Stats of discovered sites:"
    for url in "${!counts[@]}"; do
      printf "%s — %d/%d раз\n" "$url" "${counts[$url]}" "$SCAN_TIMES"
    done | sort -t ' ' -k3nr
  } >"$STATS_PATH"
  succ "Aggregation complete. See '$STATS_PATH'."
}

main() {
  check_deps
  run_scans
  aggregate_results
}

main
