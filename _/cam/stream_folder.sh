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
      # always expands to at least .env, even if it doesn't exist
      [[ -f "$dotenv" ]] || continue
      stack+=("$dotenv")
    done
    # Don't walk past project root (marked by package.json OR .git)
    [[ -f "$dir/package.json" || -d "$dir/.git" ]] && break
    # Move to parent directory for next iteration
    dir=${dir%/*}
  done

  # Source dotenv files with allexport set so that environment is modified
  # without the files needing an explicit `export` on every line.
  set -o allexport

  # Start at the top of the stack by looping backwards. This ensures that
  # nearer/more specific dotenv files override those closer to the project root.
  for ((i = 1; i <= ${#stack[@]}; i++)); do
    dotenv=${stack[-i]}
    . "$dotenv"
  done
  set +o allexport
}

redact_tty() {
  # This is mostly academic; I don't care much if the stream key is logged.
  # But I am screen-recording the output at times, so there is some logic to redacting it.
  local pfx="youtube\.com\/live2\/"
  # macOS script options are not compatible with alpine/util-linux script.
  # The awk script is Gemini's suggestion to handle ffmpeg's tty-connected log output
  # (among other issues, filled with \r instead of \n) in a graceful and unbuffered way.
  # Previously, I used `sed -u "s/${pfx}.*/${pfx}[redacted]/g"`.
  script -q /dev/null -- "$@" |
    awk -f <(
      cat <<EOF
    BEGIN {
        RS = "[\r\n]"
    }
    {
        gsub(/${pfx}.*/, "[REDACTED]")

        # Print the line and manually append the matched separator (CR or LF)
        printf "%s%s", \$0, RT
        fflush()
    }
EOF
    )

  return "${PIPESTATUS[0]}"
}

stream_folder() {
  local in_dir=${1%/}
  local out_dir=${2%/}
  local movie
  local -a movies

  if [[ ! -d $in_dir ]]; then
    echo "Error: input directory doesn't exist: $in_dir" >&2
    exit 1
  fi

  mkdir -p "$out_dir"

  # Eventually this will use proper fs event monitoring.
  # The standard on linux is inotify:
  #   inotifywait -m -e close_write --format "%f" "$in_dir" | while read -r movie; ...
  while true; do
    movies=("$in_dir"/*.mp4)
    [[ -f $movies ]] || {
      sleep 10
      continue
    }
    for movie in "${movies[@]}"; do
      [[ -f $movie ]] || continue
      redact_tty ffmpeg \
        -hide_banner \
        -readrate 1 -readrate_catchup 2 \
        -i "$movie" \
        -c copy \
        -f flv "$YT_URL" || {
        echo "Error: ffmpeg non-zero exit status." >&2
        return 1
      }
      mv "$movie" "$out_dir"
    done
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
