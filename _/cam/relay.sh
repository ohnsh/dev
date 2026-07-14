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

mmtx_url() {
  local host=${1:-r314.local}
  local addr
  addr=$(maybe_resolve "$host")

  if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ -z "$addr" ]]; then
    echo "Error resolving host: $host" >&2
    return 1
  fi

  echo "rtsp://$addr:8554/wuuk"
}

prepare_broadcast() {
  bunx youtube-client broadcast prepare
}

relay_rtsp() {
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

  ffmpeg -i "$rtsp" \
    -c:v copy \
    -c:a aac -ar 16k -b:a 32k \
    -f flv "$YT_URL"
}

buffer_rtsp() {
  local rtsp=$1

  ffmpeg -i "$rtsp" \
    -c:v copy \
    -c:a aac -ar 16k -b:a 32k \
    -f segment -segment_time 300 \
    -reset_timestamps 1 -segment_atclocktime 1 \
    -movflags frag_keyframe+empty_moov \
    -strftime 1 "cam_%Y%m%d_%H%M%S.mp4"
}

maybe_resolve() {
  local host=$1
  if [[ $host == *.local ]]; then
    avahi-resolve -4 -n "$host" | awk '{ print $2 }'
  else
    echo "$host"
  fi
}

buffer_combined() {
  local seg_length=300 # 5 minutes
  local rtsp=$1
  local host=mak.local

  PULSE_SERVER=${PULSE_SERVER:-tcp:$(maybe_resolve "$host"):4713}
  export PULSE_SERVER
  echo "Recording audio from server: $PULSE_SERVER" >&2

  ffmpeg -hide_banner -y \
    -f rtsp -i "$rtsp" \
    -f pulse -i "default" \
    -map 0:v -map 1:a \
    -c:v copy \
    -c:a aac -b:a 128k \
    -f segment -segment_time "$seg_length" \
    -reset_timestamps 1 -segment_atclocktime 1 \
    -movflags frag_keyframe+empty_moov \
    -strftime 1 -use_wallclock_as_timestamps 1 \
    "$CAM_DIR/cam_%Y%m%d_%H%M%S.mp4"
}

CAM_DIR=${CAM_DIR:-$HOME/Export/cam}

cmd=${1//-/_}
shift
if [[ $(type -t "$cmd") == "function" ]]; then
  rtsp=$(mmtx_url "$@") || exit 1
  $cmd "$rtsp"
else
  echo "$1 not a valid subcommand. Exiting." >&2
  exit 1
fi
