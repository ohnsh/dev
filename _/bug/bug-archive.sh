#!/usr/bin/env bash

BUG_DIR=$HOME/Export/bug
ARCHIVE_DIR=$BUG_DIR-archive

mkdir -p "$ARCHIVE_DIR"

for file in "$BUG_DIR"/*; do
  if [[ -n "$(fuser "$file")" ]]; then
    echo "$file currently open; skipping" >&2
    continue
  fi
  mv -nv "$file" "$ARCHIVE_DIR"
done
