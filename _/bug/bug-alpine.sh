#!/usr/bin/env bash

outdir=/recordings

# pulseaudio source names on macOS are incredibly unhelpful. For Samson G-Track Pro:
# pactl get-default-source
# Front_Left__Front_Right.2
bug_ffmpeg_pulse() {
  local addr host=${1:-mak.local}
  local seg_length=3600

  addr=$(avahi-resolve -4 -n "$host")
  export PULSE_SERVER="${PULSE_SERVER:-tcp:$addr:4713}"
  echo "Starting audio recording from server: $PULSE_SERVER"

  exec ffmpeg -y -f pulse -i "default" \
    -c:a aac -b:a 128k \
    -f segment -segment_time "$seg_length" -strftime 1 \
    "$outdir/bug_%Y%m%d_%H%M%S.aac"
}

bug_ffmpeg_pulse "$@"
