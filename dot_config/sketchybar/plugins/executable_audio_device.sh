#!/usr/bin/env bash

SOURCE="$CONFIG_DIR/helpers/audio_device.c"
CACHE_DIR="$HOME/.cache/sketchybar"
BINARY="$CACHE_DIR/audio-device"
COMPILER="/usr/bin/clang"

if [ ! -x "$BINARY" ] || [ "$SOURCE" -nt "$BINARY" ]; then
  mkdir -p "$CACHE_DIR"
  temporary_binary="$BINARY.$$"
  if "$COMPILER" \
    -Wall \
    -Wextra \
    -framework CoreAudio \
    -framework CoreFoundation \
    -framework AudioToolbox \
    "$SOURCE" \
    -o "$temporary_binary"; then
    chmod +x "$temporary_binary"
    mv "$temporary_binary" "$BINARY"
  else
    rm -f "$temporary_binary"
  fi
fi

[ -x "$BINARY" ] || exit 1
exec "$BINARY"
