#!/usr/bin/env bash

script_dir=$(dirname "${BASH_SOURCE[0]}")
[[ -f $script_dir/.env ]] && . "$script_dir/.env"
[[ -f $script_dir/lib.sh ]] || {
  echo "Error: lib.sh must exist in script directory $script_dir" >&2
  exit 1
}
. "$script_dir/lib.sh"

fill_queue() {
  local DIR=${1%/}
  local QUEUE_DIR=${2:-$DIR/_queue}
  local MAX_QUEUE_SIZE=12

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
}

stream_folder() {
  local NOFILL
  if [[ $1 == '-n' ]]; then
    NOFILL=1
    shift
  fi

  local DIR=${1%/}
  if [[ ! -d $DIR ]]; then
    echo "Please supply a valid directory." >&2
    exit 1
  fi

  local QUEUE_DIR=$DIR/_queue FINISHED_DIR=$DIR/_finished

  mkdir -p "$QUEUE_DIR" "$FINISHED_DIR"

  if [ -z $NOFILL ]; then
    fill_queue "$DIR" "$QUEUE_DIR"
  fi

  for file in "$QUEUE_DIR"/*.mp4; do
    if [ ! -e "$file" ]; then
      echo "Skipping non-existent file $file." >&2
      continue
    fi

    echo "Now streaming: $file" >&2
    if _ffmpeg_copy "$file"; then
      mv "$file" "$FINISHED_DIR"
    else
      echo "There was a problem streaming $file. Exiting." >&2
      return 1
    fi
  done
}

_fswatch() {
  # skeleton for possible "watch mode" that detects when videos are dropped into a folder
  # in limited testing this even fires when OBS splits a recording / closes an mp4 file.
  fswatch -0 "$WATCH_DIR" | while read -r -d "" file; do
    if [ -f "$file" ] && ! lsof "$file" >/dev/null 2>&1; then
      :
    fi
    sleep 1
  done

  # fswatch --event Updated $DIR | while read file
}

stream_folder "$@"
