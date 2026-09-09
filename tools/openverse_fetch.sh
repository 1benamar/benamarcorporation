#!/usr/bin/env bash
# Openverse fetcher — Python-free version using curl + bash JSON parsing.
#
# Usage:
#   bash openverse_fetch.sh --query "misty mountains" --id "hero" --target assets/img --credits assets/credits.json
#   bash openverse_fetch.sh --queries-file queries.txt --target assets/img --credits assets/credits.json
#
# queries.txt format (one per line, format: id|query|aspect|size):
#   hero|misty mountains|wide|large
#   product-1|espresso macro|tall|
#   team-maria|portrait barista||
#
# This script appends to credits.json. To regenerate clean, delete it first.

set -e

QUERY=""
ID=""
ASPECT=""
SIZE=""
QUERIES_FILE=""
TARGET=""
CREDITS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)         QUERY="$2"; shift 2 ;;
    --id)            ID="$2"; shift 2 ;;
    --aspect)        ASPECT="$2"; shift 2 ;;
    --size)          SIZE="$2"; shift 2 ;;
    --queries-file)  QUERIES_FILE="$2"; shift 2 ;;
    --target)        TARGET="$2"; shift 2 ;;
    --credits)       CREDITS="$2"; shift 2 ;;
    *)               echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$TARGET" || -z "$CREDITS" ]]; then
  echo "ERROR: --target and --credits are required"
  exit 1
fi

mkdir -p "$TARGET"
mkdir -p "$(dirname "$CREDITS")"

if [[ ! -s "$CREDITS" ]]; then
  echo "{}" > "$CREDITS"
fi

urlencode() {
  local input="$1"
  echo -n "$input" | sed -e 's/ /%20/g' -e 's/&/%26/g' -e 's/=/%3D/g' -e 's/?/%3F/g' -e 's/+/%2B/g' -e 's/,/%2C/g'
}

extract_field() {
  local field="$1"
  local json="$2"
  echo "$json" | grep -oE "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/'
}

first_renderable_url() {
  local json="$1"
  echo "$json" | grep -oE '"url"\s*:\s*"[^"]+\.(jpe?g|png|webp|gif|avif)[^"]*"' | head -1 | sed -E 's/.*"url"\s*:\s*"([^"]+)".*/\1/'
}

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

append_credit() {
  local id="$1" src="$2" title="$3" creator="$4" creator_url="$5" license="$6"
  local license_version="$7" license_url="$8" foreign_url="$9" source="${10}"

  local entry
  entry=$(cat <<ENTRY
  "$(esc "$id")": {
    "src": "$(esc "$src")",
    "title": "$(esc "$title")",
    "creator": "$(esc "$creator")",
    "creator_url": "$(esc "$creator_url")",
    "license": "$(esc "$license")",
    "license_version": "$(esc "$license_version")",
    "license_url": "$(esc "$license_url")",
    "foreign_landing_url": "$(esc "$foreign_url")",
    "source": "$(esc "$source")"
  }
ENTRY
)

  local stripped
  stripped=$(tr -d '[:space:]' < "$CREDITS")

  if [[ -z "$stripped" || "$stripped" == "{}" ]]; then
    {
      echo "{"
      echo "$entry"
      echo "}"
    } > "$CREDITS"
  else
    local last_brace_line
    last_brace_line=$(grep -n '^[[:space:]]*}[[:space:]]*$' "$CREDITS" | tail -1 | cut -d: -f1)
    if [[ -z "$last_brace_line" ]]; then
      {
        echo "{"
        echo "$entry"
        echo "}"
      } > "$CREDITS"
      return
    fi

    local prev_line=$((last_brace_line - 1))
    head -n "$prev_line" "$CREDITS" > "$CREDITS.tmp"

    {
      sed '$ s/$/,/' "$CREDITS.tmp"
      echo "$entry"
      echo "}"
    } > "$CREDITS"
    rm -f "$CREDITS.tmp"
  fi
}

process_query() {
  local id="$1" query="$2" aspect="$3" size="$4"

  if [[ -z "$id" || -z "$query" ]]; then
    echo "  [skip] missing id or query"
    return 1
  fi

  local q
  q=$(urlencode "$query")
  local url="https://api.openverse.org/v1/images/?q=$q&license=cc0,by,by-sa,pdm&mature=false&category=photograph&page_size=6"
  if [[ -n "$aspect" ]]; then url="$url&aspect_ratio=$aspect"; fi
  if [[ -n "$size" ]]; then url="$url&size=$size"; fi

  printf "  [%-18s] \"%s\" ... " "$id" "$query"

  local response
  response=$(curl -sSL -A "Premium-Website-Skill/1.0" -H "Accept: application/json" "$url" 2>/dev/null)
  if [[ -z "$response" ]]; then
    echo "FAIL no response"
    return 1
  fi

  local img_url
  img_url=$(first_renderable_url "$response")

  if [[ -z "$img_url" ]]; then
    url="https://api.openverse.org/v1/images/?q=$q&license=cc0,by,by-sa,pdm&mature=false&page_size=6"
    response=$(curl -sSL -A "Premium-Website-Skill/1.0" -H "Accept: application/json" "$url" 2>/dev/null)
    img_url=$(first_renderable_url "$response")
  fi

  if [[ -z "$img_url" ]]; then
    echo "FAIL no renderable results"
    return 1
  fi

  local title creator creator_url license license_version license_url foreign_url source
  title=$(extract_field "title" "$response")
  creator=$(extract_field "creator" "$response")
  creator_url=$(extract_field "creator_url" "$response")
  license=$(extract_field "license" "$response")
  license_version=$(extract_field "license_version" "$response")
  license_url=$(extract_field "license_url" "$response")
  foreign_url=$(extract_field "foreign_landing_url" "$response")
  source=$(extract_field "source" "$response")

  local ext
  ext=$(echo "$img_url" | grep -oE '\.(jpe?g|png|webp|gif|avif)' | head -1)
  if [[ -z "$ext" ]]; then ext=".jpg"; fi
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

  local filename="${id}${ext}"
  local dest="$TARGET/$filename"

  if curl -sSL --max-filesize 5000000 -A "Premium-Website-Skill/1.0" -o "$dest" "$img_url" 2>/dev/null; then
    local size_bytes
    size_bytes=$(wc -c < "$dest")
    if [[ $size_bytes -lt 1024 ]]; then
      echo "FAIL download too small ($size_bytes bytes)"
      rm -f "$dest"
      return 1
    fi
    echo "OK $((size_bytes / 1024)) KB"
    append_credit "$id" "assets/img/$filename" "$title" "$creator" "$creator_url" \
                  "$license" "$license_version" "$license_url" "$foreign_url" "$source"
    return 0
  else
    echo "FAIL download error"
    return 1
  fi
}

ok=0
fail=0

if [[ -n "$QUERIES_FILE" ]]; then
  echo ""
  echo "Processing queries from $QUERIES_FILE"
  echo ""
  while IFS='|' read -r line_id line_query line_aspect line_size; do
    [[ -z "$line_id" || "$line_id" =~ ^# ]] && continue
    if process_query "$line_id" "$line_query" "$line_aspect" "$line_size"; then
      ok=$((ok + 1))
    else
      fail=$((fail + 1))
    fi
    sleep 0.3
  done < "$QUERIES_FILE"
elif [[ -n "$QUERY" && -n "$ID" ]]; then
  echo ""
  echo "Processing single query: $ID = \"$QUERY\""
  echo ""
  if process_query "$ID" "$QUERY" "$ASPECT" "$SIZE"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
  fi
else
  echo "ERROR: provide either --query and --id, OR --queries-file"
  exit 1
fi

echo ""
echo "Summary: $ok ok, $fail failures"
echo "Credits: $CREDITS"

if [[ $ok -eq 0 && $fail -gt 0 ]]; then
  exit 2
fi
