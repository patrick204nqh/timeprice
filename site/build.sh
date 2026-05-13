#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

bundle config set --local path 'vendor/bundle' >/dev/null
bundle install

mkdir -p public

bundle exec rbwasm build \
  --ruby-version 3.3 \
  --target wasm32-unknown-wasip1 \
  -o public/timeprice.wasm

# Ship pre-gzipped and decompress in the browser via DecompressionStream.
# Cuts the over-the-wire size from ~52MB to ~17MB.
#
# Using a non-".gz" suffix prevents Fastly (GitHub Pages' CDN) from sniffing
# the gzip magic bytes and adding `Content-Encoding: gzip`, which would cause
# the browser to silently decompress before our DecompressionStream sees it.
gzip -kf -9 -c public/timeprice.wasm > public/timeprice.wasm.bin

# Tiny manifest so the browser can key its compiled-module cache on the
# build's content hash. Avoids the full download + compile on repeat
# visits while invalidating automatically when the wasm changes.
WASM_SHA=$(shasum -a 256 public/timeprice.wasm.bin | awk '{print $1}')
printf '{"sha256":"%s"}\n' "$WASM_SHA" > public/timeprice.wasm.meta.json

# Tailwind CSS — produce a purged stylesheet so we don't ship the play CDN
# (which warns about production use and JIT-compiles in the browser).
TW_VERSION="v3.4.17"
mkdir -p .bin
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)   TW_ASSET=tailwindcss-linux-x64 ;;
  Linux-aarch64)  TW_ASSET=tailwindcss-linux-arm64 ;;
  Darwin-x86_64)  TW_ASSET=tailwindcss-macos-x64 ;;
  Darwin-arm64)   TW_ASSET=tailwindcss-macos-arm64 ;;
  *) echo "Unsupported platform for Tailwind standalone CLI" >&2; exit 1 ;;
esac
if [[ ! -x .bin/tailwindcss ]]; then
  curl -fsSL -o .bin/tailwindcss \
    "https://github.com/tailwindlabs/tailwindcss/releases/download/${TW_VERSION}/${TW_ASSET}"
  chmod +x .bin/tailwindcss
fi
.bin/tailwindcss -c tailwind.config.js -i tailwind.css -o public/tailwind.css --minify

ls -lh public/timeprice.wasm public/timeprice.wasm.bin public/timeprice.wasm.meta.json public/tailwind.css
