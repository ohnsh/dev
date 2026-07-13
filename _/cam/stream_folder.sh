#!/usr/bin/env bash

# walk from the project root (marked by .git or package.json) to the script directory,
# sourcing all {.env,.env.*} files along the way. Sourcing happens with the `allexport`
# shell option set so that the environment is modified.
load_dotenv() {
  local script_dir=$(dirname "${BASH_SOURCE[0]}")
  local dir=$script_dir
  local dotenv i
  local stack=()

  while [[ -n $dir ]]; do
    for dotenv in "$dir"/.env{,.*}; do
      [[ -f "$dotenv" ]] || continue
      stack+=("$dotenv")
    done
    [[ -f "$dir/package.json" || -d "$dir/.git" ]] && break
    dir=${dir%/*}
  done

  set -o allexport
  for ((i = 1; i <= ${#stack[@]}; i++)); do
    dotenv=${stack[-i]}
    . "$dotenv"
  done
  set +o allexport
}

stream_folder() {
  local in_dir=${1%/}
  local out_dir=${2%/}
  local movie

  if [[ ! -d $in_dir ]]; then
    echo "Error: input directory doesn't exist: $in_dir" >&2
    exit 1
  fi

  mkdir -p "$out_dir"

  for movie in "$in_dir"/*.mp4; do
    ffmpeg \
      -readrate 1 -readrate_catchup 2 \
      -i "$movie" \
      -c copy \
      -f flv "$YT_URL" &&
      mv "$movie" "$out_dir"
  done
}

load_dotenv

if [[ -z "$YT_STREAM_KEY" ]]; then
  echo "Please provide YT_STREAM_KEY in environment or .env file." >&2
  exit 1
fi

YT_URL=rtmp://a.rtmp.youtube.com/live2/$YT_STREAM_KEY

bunx youtube-client broadcast prepare &&
  stream_folder "$@"
