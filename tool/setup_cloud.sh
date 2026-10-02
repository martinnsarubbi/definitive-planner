#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdk_dir="${FLUTTER_ROOT:-/workspace/.toolchains/flutter}"
sdk_revision=5fc346839b5d0eef006ed8404392afb4dfae428d
if [ ! -x "$sdk_dir/bin/flutter" ]; then
  mkdir -p "$(dirname "$sdk_dir")"
  git clone --depth 1 --branch 3.47.6 https://github.com/flutter/flutter.git "$sdk_dir"
fi
if [ "$(git -C "$sdk_dir" rev-parse HEAD)" != "$sdk_revision" ]; then
  echo 'Flutter SDK differs from the project pin; choose a separate FLUTTER_ROOT directory.' >&2
  exit 1
fi
cd "$repo_dir"
./tool/flutterw --version
./tool/flutterw precache --web
./tool/flutterw pub get --enforce-lockfile
