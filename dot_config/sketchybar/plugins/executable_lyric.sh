#!/usr/bin/env bash
read -r LYRIC < ~/Library/Application\ Support/sketchybar/lyric.txt
sketchybar --animate sin 20 --set lyric label="$LYRIC"
