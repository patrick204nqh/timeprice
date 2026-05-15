#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

bundle config set --local path 'vendor/bundle' >/dev/null
bundle install

mkdir -p public

# Trim Ruby stdlib components the browser never loads (REPL, docs, networking,
# inter-process). Saves ~3 MB raw / ~860 KB gzipped off cold load. We trim the
# cached prebuilt tarball directly because rbwasm short-circuits to it on every
# subsequent build (`packager/core.rb:286`), so editing the install_dir would
# get ignored. ruby_wasm 2.9's `--without-stdlib` flag only knows `enc`, hence
# the manual tar surgery.
TARBALL_GLOB="rubies/ruby-3.3-wasm32-unknown-wasip1-full-*.tar.gz"
TARBALL="$(ls $TARBALL_GLOB 2>/dev/null | head -1 || true)"

# Fresh checkouts: let rbwasm compile Ruby once so the tarball exists before
# we trim it. The wasm it produces here is unstripped and gets overwritten by
# the final build below.
if [[ -z "${TARBALL:-}" ]]; then
  echo "Bootstrap: compiling Ruby for wasm (one-time, slow)..."
  bundle exec rbwasm build \
    --ruby-version 3.3 \
    --target wasm32-unknown-wasip1 \
    -o public/timeprice.wasm
  TARBALL="$(ls $TARBALL_GLOB | head -1)"
fi

TRIM_MARKER="rubies/.stdlib-trimmed"
if [[ ! -f "$TRIM_MARKER" || "$TARBALL" -nt "$TRIM_MARKER" ]]; then
  echo "Trimming unused stdlib from $TARBALL..."
  TRIM_TMP="$(mktemp -d)"
  trap 'rm -rf "$TRIM_TMP"' EXIT
  tar -C "$TRIM_TMP" -xzf "$TARBALL"
  TRIM_ROOT="$(ls "$TRIM_TMP" | head -1)"
  RBLIB="$TRIM_TMP/$TRIM_ROOT/usr/local/lib/ruby/3.3.0"
  for d in rdoc irb reline net drb csv syntax_suggest; do
    rm -rf "$RBLIB/$d" "$RBLIB/$d.rb"
  done
  tar -C "$TRIM_TMP" -czf "$TARBALL.new" "$TRIM_ROOT"
  mv -f "$TARBALL.new" "$TARBALL"
  rm -rf "$TRIM_TMP"
  trap - EXIT
  touch "$TRIM_MARKER"
fi

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
