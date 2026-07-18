#!/usr/bin/env bash

ffmpeg="ffmpeg -hide_banner -y"

maybe_resolve() {
  local host=$1
  if [[ $host == *.local ]]; then
    avahi-resolve -4 -n "$host" | awk '{ print $2 }'
  else
    echo "$host"
  fi
}

get_rtsp_url() {
  local path=$cam addr
  addr=$(maybe_resolve "$host")

  if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ -z "$addr" ]]; then
    echo "Error resolving host: $host" >&2
    return 1
  fi

  if [[ $host == ing-*.local ]]; then
    echo "rtsp://thingino:thingino@$addr/ch0"
  else
    echo "rtsp://$addr:8554/$path"
  fi
}

redact_yt_url() {
  local pfx="youtube\.com\/live2\/"
  sed "s/${pfx}.*/${pfx}[redacted]/g"
}

get_yt_url() {
  if [[ ! -d $script_dir ]]; then
    echo "Error: computed script dir doesn't exist: $script_dir" >&2
    exit 1
  fi
  [[ -f $script_dir/.env ]] && . "$script_dir/.env"

  if [[ -z "$YT_STREAM_KEY" ]]; then
    echo "Please provide YT_STREAM_KEY in environment or .env file." >&2
    exit 1
  fi

  echo "rtmp://a.rtmp.youtube.com/live2/$YT_STREAM_KEY"
}

seg_name() {
  echo "${cam}_%Y%m%d_%H%M%S.mp4"
}

# ffmpeg options for recording to strftime-named segments on disk.
set_seg_opts() {
  local seg_length=${1:-300} # Default 5 mins
  seg_opts=(
    -f segment -segment_time "$seg_length"
    -reset_timestamps 1 -segment_atclocktime 1
    -movflags frag_keyframe+empty_moov
    -strftime 1 -use_wallclock_as_timestamps 1
  )
}

# If this is a Thingino source, clean up audio by re-encoding with the same
# ultra-low parameters as the source (I've seen YouTube reject it otherwise).
set_codec_opts() {
  local plain_codec_opts=(-c copy)
  local thingino_codec_opts=(-c:v copy -c:a aac -ar 16k -b:a 32k)

  if [[ $host == ing-*.local ]]; then
    echo "Using codec options for Thingino source" >&2
    codec_opts=("${thingino_codec_opts[@]}")
  else
    case "$path" in
    ch0 | wuuk | wuuk[0-9] | wyze[0-9])
      echo "Using codec options for Thingino source" >&2
      codec_opts=("${thingino_codec_opts[@]}")
      ;;
    *)
      codec_opts=("${plain_codec_opts[@]}")
      ;;
    esac
  fi

}

# Combine Thingino video with high-quality audio from macOS Pulseaudio server, recording
# the result to disk. This functionality is now baked directly into MediaMTX paths with
# `-patch` suffix
record_combined() {
  local -a seg_opts
  set_seg_opts

  PULSE_SERVER=${PULSE_SERVER:-tcp:$(maybe_resolve "$pulse_host"):4713}
  export PULSE_SERVER
  echo "Recording audio from server: $PULSE_SERVER" >&2

  $ffmpeg -i "$rtsp_url" \
    -f pulse -i "default" \
    -filter_complex "[1:a]adelay=1000|1000[delayed_audio]" \
    -map 0:v -map "[delayed_audio]" \
    -c:v copy -c:a aac -b:a 64k \
    "${seg_opts[@]}" \
    "$CAM_DIR/$(seg_name)"
}

record() {
  local -a seg_opts codec_opts
  set_seg_opts
  set_codec_opts

  $ffmpeg -i "$rtsp_url" \
    "${codec_opts[@]}" \
    "${seg_opts[@]}" \
    "$CAM_DIR/$(seg_name)"
}

prepare_broadcast() {
  bunx youtube-client broadcast prepare
}

relay() {
  # Thingino RTSP audio is 16 kHz / 32 kbps AAC, and apparently full of errors that need
  # to be compensated for by the decoder. Stream copying it doesn't work with YouTube.
  # Re-encoding with typical parameters causes the muxer to constantly warn about
  # out-of-order timestamps.
  #
  # However, re-encoding with the same ultra-low parameters as the input seems to work:
  # ffmpeg is quiet and YouTube accepts the stream. (The audio is atrocious but I doubt
  # the camera is capable of producing anything better.)
  local -a codec_opts
  set_codec_opts

  local yt_url
  yt_url=$(get_yt_url)

  echo "Streaming to $(echo "$yt_url" | redact_yt_url)" >&2

  prepare_broadcast || exit 1

  $ffmpeg -i "$rtsp_url" \
    "${codec_opts[@]}" \
    -f flv "$yt_url"
}

CAM_DIR=${CAM_DIR:-$HOME/Export/cam}
mkdir -p "$CAM_DIR"

script_dir=$(dirname "$0")

cmd=${1//-/_}
host=${2:-localhost}
cam=$3
pulse_host=mak.local

if [[ $host == ing-*.local ]]; then
  ing_cam=${host%%.*}
  ing_cam=${ing_cam#ing-}
  ing_cam=${ing_cam//-/}
  cam=${cam:-$ing_cam}
elif [[ -z $cam ]]; then
  echo "Assumed MediaMTX source. Must pass path (camera name) as third argument." >&2
  exit 1
fi

echo "Streaming $cam from $host" >&2

status() {
  if [[ -z "$STATUS_FIFO" || ! -w "$STATUS_FIFO" ]]; then
    return
  fi

  # Detect if the FIFO has a reader, to prevent blocking.
  if fuser "$STATUS_FIFO" &>/dev/null; then
    printf "%s\t%s\n" "$0" "$*" >"$STATUS_FIFO"
  fi
}

if [[ $(type -t "$cmd") == "function" ]]; then
  # Use mediamtx source instead of camera/Thingino directly.
  rtsp_url=$(get_rtsp_url) || exit 1
  echo "RTSP Source: $rtsp_url" >&2
  if ! $cmd; then
    status "$cmd exited with error"
  fi
else
  echo "$1 not a valid subcommand. Exiting." >&2
  exit 1
fi
