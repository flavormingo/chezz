#!/usr/bin/env bash
# Downloads the Stockfish 17 NNUE nets (not committed to git); run once after cloning.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${SCRIPT_DIR}/../chezz/Resources"
mkdir -p "$DEST"

NETS=(
  "nn-1111cefa1111.nnue"
  "nn-37f18f62d772.nnue"
)

download() {
  local net="$1"
  local out="${DEST}/${net}"
  if [[ -f "$out" ]]; then
    echo "✓ ${net} already present"
    return 0
  fi
  local hash="${net#nn-}"; hash="${hash%.nnue}"
  local urls=(
    "https://tests.stockfishchess.org/api/nn/${net}"
    "https://data.stockfishchess.org/nn/${net}"
  )
  for url in "${urls[@]}"; do
    echo "↓ ${net}  ←  ${url}"
    if curl -fL --retry 3 --connect-timeout 20 "$url" -o "$out"; then
      if [[ $(wc -c < "$out") -gt 1000000 ]]; then
        echo "✓ ${net} ($(du -h "$out" | cut -f1))"
        return 0
      fi
    fi
    rm -f "$out"
  done
  echo "✗ Failed to download ${net}. Download it manually from" >&2
  echo "  https://tests.stockfishchess.org/nns?network_name=${hash}&user= and place it in ${DEST}/" >&2
  return 1
}

echo "Fetching Stockfish neural nets into ${DEST} …"
rc=0
for net in "${NETS[@]}"; do download "$net" || rc=1; done
if [[ $rc -eq 0 ]]; then
  echo "All neural nets ready. The AI and Review features will work offline."
else
  echo "⚠️  One or more nets failed — the app will build but the engine won't run until they're present." >&2
fi
exit $rc
