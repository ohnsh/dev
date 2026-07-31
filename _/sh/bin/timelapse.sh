#!/usr/bin/env bash

# default speed 8x.
TL_RATE=${TL_RATE:-8}

# default strobe effect: 4 fps
# (1 frame every 2 real seconds at 8x)
TL_FPS=${TL_FPS:-4}
[[ TL_FPS -eq 0 ]] && TL_FPS=

# could potentially use an artificially high input `-r` to compress time
# (instead of the `setpts` filter)
tl_vf="setpts=PTS/$TL_RATE${TL_FPS:+,fps=$TL_FPS}"

ffmpeg="ffmpeg -hide_banner -y"

# VideoToolbox (Apple Silicon) hardware acceleration
timelapse_vtb() {
  local q_opts=(-q:v 60)
  # local q_opts=(-b:v 1M)

  # -hwaccel means hardware decoding
  # -hwaccel_output_format is to ensure that the frames stay on the GPU for the encoder.
  #
  # unfortunately, the filters (setpts, fps) probably run in software and require
  # downloading frames to the CPU. I don't yet know a way around it, but one must exist
  # because the filters are merely rewriting timestamps and dropping frames.
  $ffmpeg \
    -hwaccel videotoolbox \
    -hwaccel_output_format videotoolbox_vld \
    -i "$1" \
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
# See comments in `timelapse_vtb` regarding hardware acceleration; the same applies here.
timelapse_vaapi() {
  # local q_opts=(-b:v 3M)
  local q_opts=(-qp 28)

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
