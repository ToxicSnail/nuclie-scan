#!/usr/bin/env bash
# scan.sh – HTTPX-only pipeline with multi-code filtering
# Usage: ./scan.sh

set -u  # Treat unset variables as errors

# ANSI COLORS
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
info(){ echo -e "${YELLOW}[INFO] $*${NC}"; }
ok(){   echo -e "${GREEN}[OK]   $*${NC}"; }
err(){  echo -e "${RED}[ERROR] $*${NC}"; exit 1; }

# ────────────────────────── SETTINGS ────────────────────────────────────────
INPUT_FILE="sites_to_scan.txt"                 # список URL по одной в строке
HTTPX_BIN="${HTTPX_BIN:-httpx}"                # httpx CLI binary
HTTPX_OPTS_DEFAULT=(-silent -follow-redirects -json -status-code)  # default httpx flags

# Параметры парсинга JSON
STATUS_CODES_DEFAULT=(200 301 302)                       # статус-коды по умолчанию (массив)
PARSE_FIELD_DEFAULT="input"                      # поле JSON для извлечения URL
JSON_FIELD_STATUS="status_code"                # поле JSON со статус-кодом

# ─────────── REPORT DIRECTORY ──────────────────────────────────────────────
TS=$(date +"%Y-%m-%d_%H-%M-%S")
OUT_DIR="reports/${TS}"
mkdir -p "$OUT_DIR"
JSON_OUTPUT="${OUT_DIR}/httpx_${TS}.json"
LIVE_OUTPUT="${OUT_DIR}/live_sites_${TS}.txt"

# ─────────────────────── DEPENDENCY CHECK ──────────────────────────────────
check_deps() {
  info "Checking dependencies: httpx, jq"
  command -v "$HTTPX_BIN" &>/dev/null || err "Executable '$HTTPX_BIN' not found"
  command -v jq          &>/dev/null || err "Executable 'jq' not found"
  ok "All dependencies are available."
}

# ────────────────────────── CHECK FUNCTION ──────────────────────────────────
check() {
  info "Reading URLs from '$INPUT_FILE'"
  [[ -f "$INPUT_FILE" ]] || err "File '$INPUT_FILE' not found"

  info "Running httpx with flags: ${HTTPX_OPTS_DEFAULT[*]}"
  "$HTTPX_BIN" "${HTTPX_OPTS_DEFAULT[@]}" -list "$INPUT_FILE" >"$JSON_OUTPUT"
  ok "httpx JSON saved to $JSON_OUTPUT"

  info "Filtering URLs for status codes: ${STATUS_CODES_DEFAULT[*]}"
  # формируем JSON-массив кодов
  codes_json=$(printf '%s,' "${STATUS_CODES_DEFAULT[@]}")
  codes_json="[${codes_json%,}]"
  # фильтрация через jq
  jq -r --argjson codes "$codes_json" \
     --arg field "$PARSE_FIELD_DEFAULT" \
     'select(.status_code as $s | $codes | index($s)) | .[$field]' \
     "$JSON_OUTPUT" | tee "$LIVE_OUTPUT"

  cnt=$(wc -l <"$LIVE_OUTPUT")
  ok "Found $cnt live URLs (codes ${STATUS_CODES_DEFAULT[*]}), saved to $LIVE_OUTPUT"
}

# ─────────────────────────── MAIN ───────────────────────────────────────────
main() {
  check_deps
  check
}

main
