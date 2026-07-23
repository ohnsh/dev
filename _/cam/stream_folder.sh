#!/usr/bin/env bash

script_name=$(basename "$0")
script_dir=$(dirname "$0")

. "$script_dir/lib.sh" || {
  echo "Couldn't load required helper $script_dir/lib.sh." >&2
  exit 1
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

wait_folder() {
  local in_dir=$1
  local min_ready=${2:-2}
  local num_ready

  while true; do
    num_ready=0
    for movie in "$in_dir"/*.mp4; do
      if [[ ! -f $movie ]] || fuser "$movie" &>/dev/null; then
        continue
      fi
      num_ready=$((num_ready + 1))
      [[ num_ready -lt 2 ]] || return
    done

    fstatus "Waiting..."
    inotifyd - "$in_dir:wy0" | read -r
    fstatus "Continuing."
  done
}

stream_folder() {
  local in_dir=${STREAM_DIR%/} out_dir=${STREAM_ARCHIVE_DIR%/}
  local movie
  local -a movies

  if [[ ! -d $in_dir ]]; then
    echo "Error: input directory doesn't exist: $in_dir" >&2
    exit 1
  fi

  mkdir -p "$out_dir"

  # wait until in_dir contains at least 2 files that aren't open for writing.
  wait_folder "$in_dir" 2
  # ensure a broadcast is ready (usually means create one)
  bunx youtube-client broadcast prepare

  while true; do
    movies=("$in_dir"/*.mp4)

    # Very rough handling of open files that leans heavily on the second `fuser` check in
    # the for loop that follows. There's also a race condition in which a file is closed
    # after the `fuser` check but before `inotifyd` is ready.
    if [[ ! -f ${movies[0]} ]] || fuser "${movies[0]}" &>/dev/null; then
      # For now, just quit when we run out of files. If we stop and then try to continue,
      # the broadcast is over on YouTube and the stream is silently discarded. I could
      # always run `youtube-client` to create a new broadcast, but I'm not sure I want to
      # put that in a `while true` loop.
      fstatus "empty. exiting."
      break

      # fstatus "waiting"
      # inotifyd - "$in_dir:wy0" | read -r
      # fstatus "continuing"
      # continue
      # 
      # The non-busybox utility:
      #   inotifywait -m -e close_write --format "%f" "$in_dir" | while read -r movie; ...
    fi

    for movie in "${movies[@]}"; do
      [[ -f $movie ]] || continue
      fuser "$movie" &>/dev/null && break

      # Removing redact_tty wrapper for now. There are lots of gotchas, e.g. signals,
      # which could greatly complicate debugging. It was a fun exercise but it
      # probably doesn't belong in production.
      ffmpeg \
        -hide_banner \
        -readrate 1 -readrate_catchup 2 \
        -i "$movie" \
        -c copy \
        -f flv "$YT_URL" || {
        echo "Error: ffmpeg non-zero exit status." >&2
        fstatus "error"
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

STREAM_DIR=${1:-${STREAM_DIR:-$HOME/Export/cam}}
STREAM_ARCHIVE_DIR=${2:-${STREAM_ARCHIVE_DIR:-${STREAM_DIR}-archive}}

stream_folder
