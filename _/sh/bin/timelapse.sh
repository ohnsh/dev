#!/usr/bin/env bash

# default speed 10x.
TL_RATE=${TL_RATE:-10}

# default strobe effect: 2 fps
TL_FPS=${TL_FPS:-2}
[[ TL_FPS -eq 0 ]] && TL_FPS=

# could potentially use an artificially high input `-r` to compress time
# (instead of the `setpts` filter)
tl_vf="setpts=PTS/$TL_RATE${TL_FPS:+,fps=$TL_FPS}"

ffmpeg="ffmpeg -hide_banner -y"

# VideoToolbox (Apple Silicon) hardware acceleration
timelapse_vtb() {
  local q_opts=(-q:v 60)
  # local q_opts=(-b:v 1M)

  $ffmpeg -i "$1" \
    -vf "$tl_vf" \
    -map 0:v \
    -c:v hevc_videotoolbox \
    -tag:v hvc1 \
    "${q_opts[@]}" \
    "t$1"
}

timelapse_libx265() {
  $ffmpeg -i "$1" \
    -vf "$tl_vf" \
    -c:v libx265 \
    -crf 30 \
    -map 0:v \
    -tag:v hvc1 \
    "t$1"
}

# Intel VAAPI hardware acceleration using quality parameter
timelapse_vaapi() {
  # local q_opts=(-b:v 3M)
  local q_opts=()

  # when not decoding to vaapi (gpu mem)
  # -vf 'format=nv12,hwupload'
  $ffmpeg \
    -vaapi_device /dev/dri/renderD128 \
    -hwaccel vaapi \
    -hwaccel_output_format vaapi \
    -i "$1" \
    -vf "$tl_vf" \
    -map 0:v \
    -c:v hevc_vaapi \
    "${q_opts[@]}" \
    -tag:v hvc1 \
    "t$1"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  cmd=$1
  shift
  if [[ $(type -t "timelapse_$cmd") == function ]]; then
    "timelapse_$cmd" "$@"
  else
    echo "Invalid subcommand: $cmd" >&2
    exit 1
  fi
fi
