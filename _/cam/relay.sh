#!/usr/bin/env bash

# script_dir=${BASH_SOURCE[0]%/*}
script_dir=$(dirname "$0")

if [[ -z "$YT_STREAM_KEY" ]]; then
  if [[ ! -d $script_dir ]]; then
    echo "Error: computed script dir doesn't exist: $script_dir" >&2
    exit 1
  fi
  if [[ -f $script_dir/.env ]]; then
    . "$script_dir/.env"
  fi
fi

if [[ -z "$YT_STREAM_KEY" ]]; then
  echo "Please provide YT_STREAM_KEY in environment or .env file." >&2
  exit 1
fi

YT_URL=rtmp://a.rtmp.youtube.com/live2/$YT_STREAM_KEY

thingino_url() {
  local host=${1:-ing-wuuk.local}
  local addr

  addr=$(avahi-resolve -4 -n "$host" | cut -f 2)

  if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ -z "$addr" ]]; then
    echo "Error resolving host: $host" >&2
    return 1
  fi

  echo "rtsp://thingino:thingino@$addr/ch0"
}

prepare_broadcast() {
  bunx youtube-client broadcast prepare
}

relay_thingino() {
  # Thingino RTSP audio is 16 kHz / 32 kbps AAC, and apparently full of errors that need
  # to be compensated for by the decoder. Stream copying it doesn't work with YouTube.
  # Re-encoding with typical parameters causes the muxer to constantly warn about
  # out-of-order timestamps.
  #
  # However, re-encoding with the same ultra-low parameters as the input seems to work:
  # ffmpeg is quiet and YouTube accepts the stream. (The audio is atrocious but I doubt
  # the camera is capable of producing anything better.)

  local rtsp=$1

  prepare_broadcast || exit 1

  ffmpeg -hide_banner -i "$rtsp" \
    -c:v copy \
    -c:a aac -ar 16k -b:a 32k \
    -f flv "$YT_URL"
}

cmd=${1//-/_}
shift
if [[ $(type -t "$cmd") == "function" ]]; then
  # Use mediamtx source instead of camera/Thingino directly.
  rtsp=$(thingino_url "$@") || exit 1
  $cmd "$rtsp"
else
  echo "$1 not a valid subcommand. Exiting." >&2
  exit 1
fi
