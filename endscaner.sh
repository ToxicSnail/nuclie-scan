#!/usr/bin/env bash

# scan.sh – sites → httpx → nuclei pipeline with status-check for all or specific codes
# Usage: bash scan.sh [--status] [--deps] [--check] [--scan] [--all] \
#                 [--httpx "<opts>"] [--codes "<codes>"]

set -u

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
info(){ echo -e "${YELLOW}[INFO] $*${NC}"; }
ok(){   echo -e "${GREEN}[OK]   $*${NC}"; }
err(){  echo -e "${RED}[ERROR] $*${NC}"; exit 1; }

INPUT_FILE="sites_to_scan.txt"
RATE_LIMIT=100
BULK_SIZE=50
HTTPX_BIN="${HTTPX_BIN:-httpx}"
HTTPX_OPTS_DEFAULT=(-json -silent)
declare -a HTTPX_OPTS=()
STATUS_CODES_DEFAULT=()
declare -a STATUS_CODES=()

TS=$(date +"%Y-%m-%d_%H-%M-%S")
OUT_DIR="reports/${TS}"
mkdir -p "$OUT_DIR"
LIVE_SITES="${OUT_DIR}/live_sites_${TS}.txt"
JSON_FORMAT="${OUT_DIR}/httpx_${TS}.json"
OUTPUT_FILE="${OUT_DIR}/nuclei_${TS}.txt"
LOG_FILE="${OUT_DIR}/scan_${TS}.log"


check_deps() {
  info "Checking dependencies: nuclei, ${HTTPX_BIN}, jq"
  for bin in nuclei "$HTTPX_BIN" jq; do
    command -v "$bin" &>/dev/null || err "Executable '$bin' not found; install it first."
  done
  ok "All dependencies are available."
}

status_check() {
  info "Status-code scan for URLs in '$INPUT_FILE'"
  [[ -f "$INPUT_FILE" ]] || err "File '$INPUT_FILE' not found."

  if [[ ${#STATUS_CODES[@]} -gt 0 ]]; then
    local codes_csv
    codes_csv=$(IFS=,; echo "${STATUS_CODES[*]}")
    info "Showing only codes: ${STATUS_CODES[*]}"
    "$HTTPX_BIN" -list "$INPUT_FILE" -mc "$codes_csv"
  else
    info "Showing all status codes"
    "$HTTPX_BIN" -list "$INPUT_FILE" -status-code
  fi
}

check_live_sites() {
  info "Running httpx to get JSON for '$INPUT_FILE'"
  [[ -f "$INPUT_FILE" ]] || err "File '$INPUT_FILE' not found."
  "$HTTPX_BIN" "${HTTPX_OPTS[@]}" -list "$INPUT_FILE" -json >"$JSON_FORMAT"
  ok "httpx JSON saved to $JSON_FORMAT"
  
  if [[ ${#STATUS_CODES[@]} -gt 0 ]]; then
    local codes_json
    codes_json=$(printf '%s,' "${STATUS_CODES[@]}")
    codes_json="[${codes_json%,}]"
    info "Filtering JSON for codes: ${STATUS_CODES[*]}"
    jq -r --argjson codes "$codes_json" \
       'select(.status_code as $s | $codes | index($s)) | .url' \
       "$JSON_FORMAT" >"$LIVE_SITES"
  else
    info "No codes filter; taking all URLs"
    jq -r '.url' "$JSON_FORMAT" >"$LIVE_SITES"
  fi
  local cnt; cnt=$(wc -l <"$LIVE_SITES")
  [[ $cnt -gt 0 ]] || err "No URLs found after filtering."
  ok "Found $cnt URLs → $LIVE_SITES"
}

run_nuclei() {
  info "Running nuclei on '$LIVE_SITES'"
  [[ -f "$LIVE_SITES" ]] || err "File '$LIVE_SITES' not found; run --check first."
  nuclei -l "$LIVE_SITES" \
         -follow-redirects \
         -rate-limit "$RATE_LIMIT" \
         -bulk-size "$BULK_SIZE" \
         -o "$OUTPUT_FILE" 2>>"$LOG_FILE"
  ok "Nuclei results → $OUTPUT_FILE"
}

usage() {
  cat <<EOF
Usage: bash scan.sh [options]

Options:
  --status           Print each URL with HTTP status code to console
                     (all codes by default, or filtered via --codes)
  --deps             Check dependencies (nuclei, httpx, jq)
  --check            httpx JSON + filter by codes → $LIVE_SITES
  --scan             Run nuclei → $OUTPUT_FILE
  --all              deps + status + check + scan (default)
  --httpx "<opts>"     Extra httpx flags (e.g. "-timeout 10")
  --codes "<codes>"    Specify status codes for filtering (e.g. "200 301 400")
  -h, --help         Show this message

All reports are saved under: $OUT_DIR
EOF
}

main() {
  [[ $# -eq 0 ]] && set -- --all
  declare -a STEPS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) STEPS+=(status) ;;  
      --deps)   STEPS+=(deps)   ;;  
      --check)  STEPS+=(check)  ;;  
      --scan)   STEPS+=(scan)   ;;  
      --all)    STEPS+=(deps status check scan) ;;  
      --httpx)  shift; read -r -a HTTPX_OPTS <<< "$1" ;;  
      --codes)  shift; read -r -a STATUS_CODES <<< "$1" ;; 
      -h|--help) usage; exit 0 ;; 
      *) err "Unknown option: $1" ;; 
    esac
    shift
  done

  [[ ${#HTTPX_OPTS[@]} -eq 0 ]] && HTTPX_OPTS=("${HTTPX_OPTS_DEFAULT[@]}")
  [[ ${#STATUS_CODES[@]} -eq 0 ]] && STATUS_CODES=("")

  for step in "${STEPS[@]}"; do
    case "$step" in
      deps)   check_deps    ;; 
      status) status_check  ;; 
      check)  check_live_sites ;; 
      scan)   run_nuclei    ;; 
    esac
  done
}

main "$@"
