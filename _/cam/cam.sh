#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$0")

. "$SCRIPT_DIR/lib.sh" || {
  echo "Couldn't load required helper $SCRIPT_DIR/lib.sh." >&2
  exit 1
}

maybe_resolve() {
  local host=$1
  if [[ $host == *.local ]]; then
    # use our library function
    mdns_resolve "$host"
    # avahi-resolve -4 -n "$host" | awk '{ print $2 }'
  else
    echo "$host"
  fi
}

get_rtsp_url() {
  local path=$CAM addr
  addr=$(maybe_resolve "$HOST")

  if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ -z "$addr" ]]; then
    echo "Error resolving host: $HOST" >&2
    return 1
  fi

  if [[ $HOST == ing-*.local ]]; then
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
  [[ -f $SCRIPT_DIR/.env ]] && . "$SCRIPT_DIR/.env"

  if [[ -z "$YT_STREAM_KEY" ]]; then
    echo "Please provide YT_STREAM_KEY in environment or .env file." >&2
    exit 1
  fi

  echo "rtmp://a.rtmp.youtube.com/live2/$YT_STREAM_KEY"
}

# ffmpeg options for recording to strftime-named segments on disk.
set_seg_opts() {
  if ! declare -p seg_opts &>/dev/null; then
    echo "seg_opts array must be in scope when calling set_seg_opts" >&2
    return 1
  fi
  local seg_length=${1:-300} # Default 5 mins

  seg_opts=(
    -f segment -segment_time "$seg_length"
    -reset_timestamps 1 -segment_atclocktime 1
    -movflags +hybrid_fragmented
    -strftime 1 -use_wallclock_as_timestamps 1
  )
}

# If this is a Thingino source, clean up audio by re-encoding with the same
# ultra-low parameters as the source (I've seen YouTube reject it otherwise).
set_codec_opts() {
  if ! declare -p codec_opts &>/dev/null; then
    echo "codec_opts array must be in scope when calling set_codec_opts" >&2
    return 1
  fi
  local plain_codec_opts=(-c copy)
  local thingino_codec_opts=(-c:v copy -c:a aac -ar 16k -b:a 32k)

  if [[ $HOST == ing-*.local ]]; then
    echo "Using codec options for Thingino source" >&2
    codec_opts=("${thingino_codec_opts[@]}")
  else
    case "$path" in
    ch0 | wuuk | wuuk[0-9] | wyze[0-9])
      echo "Using codec options for Thingino source" >&2
      codec_opts=("${thingino_codec_opts[@]}")
      ;;
    *)
      echo "Assuming clean audio; performing stream copy." >&2
      codec_opts=("${plain_codec_opts[@]}")
      ;;
    esac
  fi

  local rtsp_in=$1
  local codec_in
  codec_in=$(
    ffprobe -v error \
      -select_streams v:0 \
      -show_entries stream=codec_name \
      -of default=noprint_wrappers=1:nokey=1 \
      "$rtsp_in"
  )

  if [[ $codec_in == "hevc" ]]; then
    echo "H.265 detected in RTSP stream; adding hvc1 tag to recorded files" >&2
    codec_opts+=(-tag:v hvc1)
  fi
}

set_metadata_opts() {
  if ! declare -p metadata_opts &>/dev/null; then
    echo "metadata_opts array must be in scope when calling set_metadata_opts" >&2
    return 1
  fi

  metadata_opts=(-metadata "creation_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")")
}

# Combine Thingino video with high-quality audio from macOS Pulseaudio server, recording
# the result to disk. This functionality is now baked directly into MediaMTX paths with
# `-patch` suffix
record_combined() {
  local -a seg_opts
  set_seg_opts

  # environment variable used by libpulse
  PULSE_SERVER=${PULSE_SERVER:-tcp:$(maybe_resolve "$PULSE_HOST"):4713}
  export PULSE_SERVER
  echo "Recording audio from server: $PULSE_SERVER" >&2

  ffmpeg -v warning -y \
    -i "$RTSP_URL" \
    -f pulse -i "default" \
    -filter_complex "[1:a]adelay=1000|1000[delayed_audio]" \
    -map 0:v -map "[delayed_audio]" \
    -c:v copy -c:a aac -b:a 64k \
    "${seg_opts[@]}" \
    "$cam_dir_fmt/$seg_name"
}

record() {
  local -a seg_opts codec_opts metadata_opts
  set_seg_opts 1200 # 20 min
  set_codec_opts "$RTSP_URL"
  set_metadata_opts

  ffmpeg -v warning -y \
    -i "$RTSP_URL" \
    "${codec_opts[@]}" \
    "${seg_opts[@]}" \
    "${metadata_opts[@]}" \
    "$cam_dir_fmt/$seg_name"
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

  ffmpeg -v warning \
    -i "$RTSP_URL" \
    "${codec_opts[@]}" \
    -f flv "$yt_url"
}

supervise_record() {
  local seg_name
  # path to pass to mkdir
  local cam_dir=$CAM_BASE_DIR/$(date +%F)/${CAM}/_raw
  # path to pass to ffmpeg.
  # it resolves to current date even if recording started on a previous day.
  local cam_dir_fmt=$CAM_BASE_DIR/%Y-%m-%d/${CAM}/_raw

  while true; do
    # crucial to prevent infinite loop
    mkdir -p "$cam_dir" || {
      fstatus "mkdir failed; exiting."
      exit 1
    }
    seg_name=${CAM}_%Y%m%d_%H%M%S.mp4
    echo "Segment format: $cam_dir/$seg_name" >&2

    if ! "$CMD"; then
      status=$?

      cam_dir=$CAM_BASE_DIR/$(date +%F)/${CAM}/_raw
      if [[ ! -d $cam_dir ]]; then
        fstatus_notify "Detected date change. Creating $cam_dir and retrying..."
        # only condition where loop continues
        continue
      fi
      # unknown error; don't try to recover
      fstatus_notify "$CMD exited with error ($status)"
      exit $status
    fi
    # get out of this loop on success
    break
  done
}

init() {
  HOST=${1:-localhost}
  CAM=$2

  # somewhat obsolete cruft now that I always stream from mediaMTX.
  # the primary benefit is that the cameras never have more than 1 connection to service.
  if [[ $HOST == ing-*.local ]]; then
    # infer camera name (for file paths) from camera hostname
    ing_cam=${HOST%%.*}
    ing_cam=${ing_cam#ing-}
    ing_cam=${ing_cam//-/}
    CAM=${CAM:-$ing_cam}
  elif [[ -z $CAM ]]; then
    echo "Assumed MediaMTX source. Must pass path (camera name) as third argument." >&2
    exit 1
  fi

  # Either points to mediamtx or camera/Thingino directly.
  RTSP_URL=$(get_rtsp_url) || exit 1
  echo "RTSP Source: $RTSP_URL" >&2

  echo "Streaming $CAM from $HOST" >&2
}

# configurable defaults
CAM_BASE_DIR=${CAM_BASE_DIR:-$HOME/Export/cam-proxy/recordings}
PULSE_HOST=${PULSE_HOST:-mak.local}

CMD=${1//-/_}
shift

case "$CMD" in
record*)
  init "$@"
  supervise_record
  ;;
relay)
  init "$@"
  relay
  ;;
notify)
  # test ntfy.sh functionality
  fstatus_notify "$@"
  ;;
*)
  echo "Invalid subcommand: $CMD" >&2
  exit 1
  ;;
esac
