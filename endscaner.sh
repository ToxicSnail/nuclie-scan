#!/usr/bin/env bash
# scan.sh – HTTPX-only pipeline with whitelist and blacklist filtering
# Usage: ./scan.sh

set -u  # Treat unset variables as errors

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
info(){ echo -e "${YELLOW}[INFO] $*${NC}"; }
ok(){   echo -e "${GREEN}[OK]   $*${NC}"; }
err(){  echo -e "${RED}[ERROR] $*${NC}"; exit 1; }

INPUT_FILE="sites_to_scan.txt"                 # список URL по одной в строке
HTTPX_BIN="${HTTPX_BIN:-httpx}"                # httpx CLI binary
HTTPX_OPTS_DEFAULT=(-silent -follow-redirects -json -status-code)  # default httpx flags

PARSE_FIELD_DEFAULT="url"                      # поле JSON для извлечения URL
JSON_FIELD_STATUS="status_code"                # поле JSON со статус-кодом

WHITELIST_CODES_DEFAULT=()                 
BLACKLIST_CODES_DEFAULT=()                   

TS=$(date +"%Y-%m-%d_%H-%M-%S")
OUT_DIR="reports/${TS}"
mkdir -p "$OUT_DIR"
JSON_OUTPUT="${OUT_DIR}/httpx_${TS}.json"
LIVE_OUTPUT="${OUT_DIR}/live_sites_${TS}.txt"

check_deps() {
  info "Checking dependencies: httpx, jq"
  command -v "$HTTPX_BIN" &>/dev/null || err "Executable '$HTTPX_BIN' not found"
  command -v jq          &>/dev/null || err "Executable 'jq' not found"
  ok "All dependencies are available."
}

check() {
  info "Reading URLs from '$INPUT_FILE'"
  [[ -f "$INPUT_FILE" ]] || err "File '$INPUT_FILE' not found"

  info "Running httpx with flags: ${HTTPX_OPTS_DEFAULT[*]}"
  "$HTTPX_BIN" "${HTTPX_OPTS_DEFAULT[@]}" -list "$INPUT_FILE" >"$JSON_OUTPUT"
  ok "httpx JSON saved to $JSON_OUTPUT"

  if (( ${#WHITELIST_CODES_DEFAULT[@]} > 0 )); then
    info "Applying whitelist codes: ${WHITELIST_CODES_DEFAULT[*]}"
    codes_json=$(printf '%s,' "${WHITELIST_CODES_DEFAULT[@]}")
    codes_json="[${codes_json%,}]"
    jq -r --argjson codes "$codes_json" \
       --arg field "$PARSE_FIELD_DEFAULT" \
       'select(.status_code as $s | $codes | index($s)) | .[$field]' \
       "$JSON_OUTPUT" | tee "$LIVE_OUTPUT"
  elif (( ${#BLACKLIST_CODES_DEFAULT[@]} > 0 )); then
    info "Applying blacklist codes: ${BLACKLIST_CODES_DEFAULT[*]}"
    codes_json=$(printf '%s,' "${BLACKLIST_CODES_DEFAULT[@]}")
    codes_json="[${codes_json%,}]"
    jq -r --argjson codes "$codes_json" \
       --arg field "$PARSE_FIELD_DEFAULT" \
       'select((.status_code as $s | $codes | index($s)) | not) | .[$field]' \
       "$JSON_OUTPUT" | tee "$LIVE_OUTPUT"
  else
    info "No whitelist/blacklist specified; taking all URLs"
    jq -r --arg field "$PARSE_FIELD_DEFAULT" '.[$field]' "$JSON_OUTPUT" | tee "$LIVE_OUTPUT"
  fi

  cnt=$(wc -l <"$LIVE_OUTPUT")
  ok "Found $cnt URLs after filtering, saved to $LIVE_OUTPUT"
}

main() {
  check_deps
  check
}

main
