#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/.env"
. "$SCRIPT_DIR/lib.sh"

stream_folder() {
  local DIR=${1%/}
  local QUEUE_DIR=$DIR/_queue FINISHED_DIR=$DIR/_finished
  local MAX_QUEUE_SIZE=12

  mkdir -p "$QUEUE_DIR" "$FINISHED_DIR"

  shopt -s nullglob
  local files=("$DIR"/*.mp4) queue_files=("$QUEUE_DIR"/*.mp4)
  shopt -u nullglob

  local headroom=$((MAX_QUEUE_SIZE - ${#queue_files[@]}))

  echo "Queue has room for $headroom more files." >&2
  if [[ ${#files[@]} -gt $headroom ]]; then
    files=("${files[@]:0:$headroom}")
  fi

  local unsafe_test prefix value
  for file in "${files[@]}"; do
    unsafe_test=$(
      lsof -F fan "$file" 2>/dev/null | while read -r line; do
        prefix=${line:0:1}
        value=${line:1}

        if [[ $prefix == a && $value == [wu] ]]; then
          echo "$file"
        fi
      done
    )
    if [[ $unsafe_test ]]; then
      echo "$file open for writing; skipping." >&2
      continue
    fi

    mv -n "$file" "$QUEUE_DIR"
  done

  for file in "$QUEUE_DIR"/*.mp4; do
    if [ ! -e "$file" ]; then
      echo "Skipping non-existant file $file." >&2
      continue
    fi

    if _ffmpeg_copy "$file"; then
      mv "$file" "$FINISHED_DIR"
    else
      echo "There was a problem streaming $file. Exiting." >&2
      return 1
    fi
  done

  # while true; do
  #   # If the folder is empty, wait 5 seconds and check again
  #     echo "Queue empty. Waiting for videos..."
  #     sleep 5
  #     continue
  #   fi
  # done
}

_fswatch() {
  fswatch -0 "$WATCH_DIR" | while read -d "" file; do
    # This block triggers instantly only when an .mp4 file changes/closes
    if [ -f "$file" ] && ! lsof "$file" >/dev/null 2>&1; then
      sleep 1
      # Insert your sleep and mv logic here
    fi
  done

  # fswatch --event Updated $DIR | while read file
}

stream_folder "$@"
