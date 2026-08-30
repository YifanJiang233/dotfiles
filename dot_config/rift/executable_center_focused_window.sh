#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/helpers/center_focused_window.c"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rift"
BINARY="$CACHE_DIR/center-focused-window"
COMPILER=/usr/bin/clang

[ -r "$SOURCE" ] || exit 1
[ -x "$COMPILER" ] || exit 1

if [ ! -x "$BINARY" ] || [ "$SOURCE" -nt "$BINARY" ]; then
  mkdir -p "$CACHE_DIR" || exit 1
  temporary_binary="$BINARY.$$"
  if "$COMPILER" \
    -Wall \
    -Wextra \
    -framework ApplicationServices \
    -framework CoreGraphics \
    "$SOURCE" \
    -o "$temporary_binary"; then
    chmod +x "$temporary_binary"
    mv -f "$temporary_binary" "$BINARY"
  else
    rm -f "$temporary_binary"
    exit 1
  fi
fi

exec "$BINARY" "$@"
