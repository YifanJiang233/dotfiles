#!/bin/sh
set -eu

/opt/homebrew/bin/rift-cli execute workspace move-window --follow "$1"
