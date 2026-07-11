#!/usr/bin/env bash

BUGDIR=${BUGDIR:-/recordings}

maybe_resolve() {
  local host=$1
  if [[ $host == *.local ]] && which avahi-resolve >/dev/null 2>&1; then
    avahi-resolve -4 -n "$host" | cut -f 2
  else
    echo "$host"
  fi
}
# pulseaudio source names on macOS are incredibly unhelpful. For Samson G-Track Pro:
# pactl get-default-source
# Front_Left__Front_Right.2
bug_ffmpeg_pulse() {
  local host=${1:-mak.local}
  local seg_length=3600
  host=$(maybe_resolve "$host")

  export PULSE_SERVER="${PULSE_SERVER:-tcp:$host:4713}"
  echo "Starting audio recording from server: $PULSE_SERVER"

  exec ffmpeg -hide_banner -y \
    -f pulse -i "default" \
    "${codec[@]}" \
    -f segment -segment_time "$seg_length" \
    -reset_timestamps 1 -segment_atclocktime 1 \
    -strftime 1 -use_wallclock_as_timestamps 1 \
    "$BUGDIR/bug_%Y%m%d_%H%M%S.$ext"
    #-use_localtime 1 # not working, perhaps only valid for hls segments
}

bug_aac() {
  local codec=(-c:a aac -b:a 128k)
  local ext=aac
  bug_ffmpeg_pulse "$@"
}

bug_opus() {
  local codec=(-c:a libopus -b:a 64k)
  local ext=opus
  bug_ffmpeg_pulse "$@"
}

mkdir -p "$BUGDIR"

bug_opus "$@"
