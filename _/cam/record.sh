mmtx_url() {
  local host=${1:-box.local}
  local path=${2:-wuuk}
  local addr
  addr=$(maybe_resolve "$host")

  if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ -z "$addr" ]]; then
    echo "Error resolving host: $host" >&2
    return 1
  fi

  echo "rtsp://$addr:8554/$path"
}

maybe_resolve() {
  local host=$1
  if [[ $host == *.local ]]; then
    avahi-resolve -4 -n "$host" | awk '{ print $2 }'
  else
    echo "$host"
  fi
}

# Basic save of Thingino RTSP stream to disk. Clean up audio by re-encoding with the same
# ultra-low parameters as the source (I've seen YouTube reject it otherwise).
record_rtsp() {
  local rtsp=$1

  ffmpeg -hide_banner -i "$rtsp" \
    -c:v copy \
    -c:a aac -ar 16k -b:a 32k \
    -f segment -segment_time 300 \
    -reset_timestamps 1 -segment_atclocktime 1 \
    -movflags frag_keyframe+empty_moov \
    -strftime 1 "cam_%Y%m%d_%H%M%S.mp4"
}

# Combine Thingino video with high-quality audio from macOS Pulseaudio server, recording
# the result to disk. Works surprisingly well, but I'm now doing it within MediaMTX so
# may not get much use out of this function.
record_combined() {
  local rtsp=$1
  local pulse_host=mak.local
  local seg_length=300 # 5 minutes

  PULSE_SERVER=${PULSE_SERVER:-tcp:$(maybe_resolve "$pulse_host"):4713}
  export PULSE_SERVER
  echo "Recording audio from server: $PULSE_SERVER" >&2

  ffmpeg -hide_banner -y \
    -f rtsp -i "$rtsp" \
    -f pulse -i "default" \
    -map 0:v -map 1:a \
    -c:v copy -c:a aac -b:a 64k \
    -f segment -segment_time "$seg_length" \
    -reset_timestamps 1 -segment_atclocktime 1 \
    -movflags frag_keyframe+empty_moov \
    -strftime 1 -use_wallclock_as_timestamps 1 \
    "$CAM_DIR/cam_%Y%m%d_%H%M%S.mp4"
}

record_patched() {
  local rtsp=$1
  local seg_length=300 # 5 minutes

  ffmpeg -hide_banner -y \
    -i "$rtsp" -c copy \
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
  # Use mediamtx source instead of camera/Thingino directly.
  rtsp=$(mmtx_url "$@") || exit 1
  $cmd "$rtsp"
else
  echo "$1 not a valid subcommand. Exiting." >&2
  exit 1
fi
