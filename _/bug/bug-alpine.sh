#!/usr/bin/env bash

BUGDIR=${BUGDIR:-/recordings}

# pulseaudio source names on macOS are incredibly unhelpful. For Samson G-Track Pro:
# pactl get-default-source
# Front_Left__Front_Right.2
bug_ffmpeg_pulse() {
  local host=${1:-mak.local}
  local seg_length=3600

  export PULSE_SERVER="${PULSE_SERVER:-tcp:$host:4713}"
  echo "Starting audio recording from server: $PULSE_SERVER"

  # possibly use `exec`
  ffmpeg -hide_banner -y \
    -f pulse -i "default" \
    -c:a aac -b:a 128k \
    -f segment -segment_time "$seg_length" \
    -strftime 1 "$BUGDIR/bug_%Y%m%d_%H%M%S.aac"
}

mkdir -p "$BUGDIR"

bug_ffmpeg_pulse "$@"
