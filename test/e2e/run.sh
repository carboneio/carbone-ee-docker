#!/usr/bin/env bash
# End-to-end tests of a Carbone EE image.
# Usage: test/e2e/run.sh <image>      e.g. test/e2e/run.sh carbone/carbone-ee:full-5.15.4
#
# Starts the image twice (Azure plugin on Azurite, S3 plugin on S3Mock) and, on each instance:
#   - uploads templates and checks they land in the storage, then are removed from it on delete,
#   - renders the DOCX template without conversion (every variant, slim included),
#   - renders a PDF with every converter shipped in the image (LibreOffice, OnlyOffice, Chrome)
#     and checks the PDF text contains the injected data,
#   - checks the render is stored in the storage, then removed from it once downloaded.
# Requires: docker compose, curl, jq, unzip, pdftotext and pdfinfo (poppler-utils).

set -euo pipefail

IMAGE="${1:?Usage: $0 <image>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(mktemp -d)"

export CARBONE_IMAGE="$IMAGE"
export AZURE_PORT="${AZURE_PORT:-4101}"
export S3_PORT="${S3_PORT:-4102}"
export S3MOCK_PORT="${S3MOCK_PORT:-9090}"
COMPOSE=(docker compose -f "$HERE/compose.yml" -p carbone-e2e)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILURES=0
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; FAILURES=$((FAILURES + 1)); }
info() { echo -e "${YELLOW}→${NC} $1"; }

cleanup() {
  if [ "$FAILURES" -ne 0 ] || [ -n "${KEEP_LOGS:-}" ]; then
    "${COMPOSE[@]}" logs carbone-azure carbone-s3 || true
  fi
  "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$OUT"
}
trap cleanup EXIT

for cmd in docker curl jq unzip pdftotext pdfinfo; do
  command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd"; exit 1; }
done

DATA='{
  "invoiceNumber": "INV-E2E-042",
  "client": { "name": "Acme Corp" },
  "items": [
    { "description": "Carbone License", "quantity": 1, "unitPrice": 500 },
    { "description": "Onboarding",      "quantity": 2, "unitPrice": 150 }
  ],
  "totalAmount": 800
}'
EXPECTED_TEXT=("INV-E2E-042" "Acme Corp" "Carbone License" "Onboarding" "800")
# PDF "Producer" written by each converter
expected_producer() {
  case $1 in
    L) echo "LibreOffice" ;;
    O) echo "ONLYOFFICE" ;;
    C) echo "Skia/PDF" ;;
  esac
}

# ── Converters shipped in this image variant ──────────────────────────────────
CONVERTERS=$(docker run --rm --entrypoint sh "$IMAGE" -c '
  ls -d /opt/libreoffice* >/dev/null 2>&1 && echo L
  [ -n "$CARBONE_EE_ONLYOFFICEPATH" ] && echo O
  [ -n "$CARBONE_EE_CHROMEPATH" ] && echo C
  true')
info "Image $IMAGE, converters: $(echo $CONVERTERS)"

# ── Storage helpers: list the object names of a container/bucket ─────────────
list_azure() {
  "${COMPOSE[@]}" run --rm -T azure-cli az storage blob list -c "$1" --query "[].name" -o tsv 2>/dev/null
}
list_s3() {
  curl -sf "http://127.0.0.1:$S3MOCK_PORT/$1" | grep -o '<Key>[^<]*</Key>' | sed 's/<[^>]*>//g'
}

# expect_stored <backend> <container> <name> <present|absent>
# Deletions may be asynchronous in the plugins, so retry for a few seconds.
expect_stored() {
  local backend=$1 container=$2 name=$3 state=$4 i
  for i in 1 2 3 4 5; do
    if "list_$backend" "$container" | grep -qxF -e "$name"; then
      [ "$state" = present ] && { pass "$name is in $backend/$container"; return; }
    else
      [ "$state" = absent ] && { pass "$name is no longer in $backend/$container"; return; }
    fi
    sleep 1
  done
  fail "$name should be $state in $backend/$container"
}

wait_ready() {
  local url=$1 i
  for i in $(seq 1 90); do
    curl -sf "$url/status" >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

upload_template() {
  curl -sf -X POST "$1/template" -F "template=@$2" | jq -r '.data.templateId // empty'
}

# check_text <label> <text>: the rendered document must contain the injected data
check_text() {
  local label=$1 text=$2 expected missing=()
  for expected in "${EXPECTED_TEXT[@]}"; do
    grep -qF -e "$expected" <<<"$text" || missing+=("$expected")
  done
  if [ ${#missing[@]} -eq 0 ]; then
    pass "$label: document contains the rendered data"
  else
    fail "$label: document is missing: ${missing[*]}"
  fi
}

# render <url> <backend> <templateId> <format: docx|pdf> [converter: L|O|C]
# Renders, checks the result is stored, downloads it, checks its content, and that it left the storage.
render() {
  local url=$1 backend=$2 template_id=$3 format=$4 converter=${5:-} label body render_id file producer
  label="$format${converter:+ via converter $converter}"
  body=$(jq -n --argjson data "$DATA" --arg f "$format" --arg c "$converter" \
    '{data: $data, convertTo: $f} + (if $c == "" then {} else {converter: $c} end)')
  render_id=$(curl -sf -X POST "$url/render/$template_id" -H "Content-Type: application/json" -d "$body" \
    | jq -r '.data.renderId // empty') || true
  if [ -z "$render_id" ]; then
    fail "$label: render failed"
    return
  fi
  expect_stored "$backend" renders "$render_id" present

  file="$OUT/$backend-$format-$converter"
  if ! curl -sf -o "$file" "$url/render/$render_id"; then
    fail "$label: download of render $render_id failed"
    return
  fi

  if [ "$format" = docx ]; then
    check_text "$label" "$(unzip -p "$file" word/document.xml 2>/dev/null || true)"
  else
    if [ "$(head -c 5 "$file")" != "%PDF-" ]; then
      fail "$label: not a PDF"
      return
    fi
    check_text "$label" "$(pdftotext "$file" - 2>/dev/null || true)"
    # The PDF producer proves which engine actually did the conversion
    producer=$(pdfinfo "$file" 2>/dev/null | sed -n 's/^Producer: *//p')
    if grep -q "^$(expected_producer "$converter")" <<<"$producer"; then
      pass "$label: produced by $producer"
    else
      fail "$label: produced by '$producer', expected $(expected_producer "$converter")"
    fi
  fi
  expect_stored "$backend" renders "$render_id" absent
}

# test_instance <name> <url> <backend> <regex of the log line printed for each connected storage>
test_instance() {
  local name=$1 url=$2 backend=$3 log_marker=$4 docx_id html_id converter connected i
  echo ""
  info "$name ($url)"

  if ! wait_ready "$url"; then
    fail "server did not start"
    return
  fi
  pass "server is up"

  # Logs may be flushed after /status answers
  connected=false
  for i in $(seq 1 10); do
    [ "$("${COMPOSE[@]}" logs "carbone-$backend" | grep -cE "$log_marker")" -ge 2 ] && { connected=true; break; }
    sleep 1
  done
  if $connected; then
    pass "plugin connected to the templates and renders storages"
  else
    fail "plugin not connected: expected 2 log lines matching '$log_marker'"
    "${COMPOSE[@]}" logs "carbone-$backend" | grep -iE "plugin|storage|S3|azure" || true
  fi

  docx_id=$(upload_template "$url" "$HERE/templates/invoice.docx") || true
  html_id=$(upload_template "$url" "$HERE/templates/invoice.html") || true
  if [ -z "$docx_id" ] || [ -z "$html_id" ]; then
    fail "template upload failed"
    return
  fi
  pass "templates uploaded"
  expect_stored "$backend" templates "$docx_id" present

  # No conversion: works on every variant, slim included
  render "$url" "$backend" "$docx_id" docx

  for converter in $CONVERTERS; do
    # Chrome only converts HTML, LibreOffice and OnlyOffice convert the DOCX
    if [ "$converter" = C ]; then
      render "$url" "$backend" "$html_id" pdf C
    else
      render "$url" "$backend" "$docx_id" pdf "$converter"
    fi
  done

  for id in "$docx_id" "$html_id"; do
    curl -sf -X DELETE "$url/template/$id" >/dev/null || fail "delete of template $id failed"
  done
  expect_stored "$backend" templates "$docx_id" absent
}

info "Starting the stack"
"${COMPOSE[@]}" up -d --quiet-pull

test_instance "Azure Blob Storage plugin" "http://127.0.0.1:$AZURE_PORT" azure "Access on (templates|renders) : 🟢"
test_instance "S3 plugin" "http://127.0.0.1:$S3_PORT" s3 "(Templates|Renders) S3 Bucket Connected"

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${GREEN}All end-to-end tests passed${NC}"
else
  echo -e "${RED}$FAILURES end-to-end check(s) failed${NC}"
  exit 1
fi
