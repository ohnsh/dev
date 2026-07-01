#!/usr/bin/env bash

FFMPEG="ffmpeg -hide_banner -v warning"

# default of 10x timelapse.
RATE=${RATE:-10}

_timelapse() {
  # could potentially use an artificially high input `-r` to compress time
  # (instead of the `setpts` filter)
  # -r may not be doing any good here (and the input framerate likely isn't 30)
  $FFMPEG -i "$1" -vf "setpts=PTS/$RATE" -r 30    \
  -map 0:0 -c:v hevc_videotoolbox -tag:v hvc1  \
  -b:v 1M "t$1"
}

_wyze_hour() {
  local _hour=$1 min
  pushd "$_hour" >/dev/null || exit 1
  local hour=$(basename "$(pwd)")

  if [ -e "../$hour.mp4" ]; then
    printf "  Skipping hour %s...\n" "$hour"
    popd >/dev/null || return 1
    return
  fi

  printf "  Processing hour %s...\n" "$hour"
  for min in ??.mp4; do
    if [ -e "t$min" ]; then
      printf "    Skipping minute %s...\r" "$min"
      continue
    fi

    printf "    Processing minute %s...\r" "$min"
    _timelapse "$min"
  done

  echo
  $FFMPEG -f concat -safe 0 -i <(printf "file '%s'\n" t??.mp4) -c copy \
    "../$hour.mp4"

  popd >/dev/null || return 1
}

_wyze_day() {
  # find "$day" -name "??.mp4" | while read file; do
  local day

  for day; do
    pushd "$day" >/dev/null || return 1

    echo "Processing day $day..."
    for hour in ??; do
      _wyze_hour "$hour" || break
    done

    popd >/dev/null || return 1
  done
}

if [[ ${BASH_SOURCE[0]} = "$0" ]]; then
  if [[ $1 = "-h" ]]; then
    shift
    _wyze_hour "$@"
  else
    _wyze_day "$@"
  fi
fi
