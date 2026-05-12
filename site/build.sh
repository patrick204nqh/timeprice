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

ls -lh public/timeprice.wasm
