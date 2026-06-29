#!/bin/sh

FFMPEG="ffmpeg -hide_banner -v warning"

# default of 10x timelapse.
RATE=${RATE:-10}

_timelapse() {
  $FFMPEG -i "$1" -vf "setpts=PTS/$RATE" -r 30    \
  -map 0:0 -c:v hevc_videotoolbox -tag:v hvc1  \
  -b:v 1M "t$1"
}

_wyze_hour() {
  local _hour=$1 min
  pushd "$_hour" >/dev/null || exit 1
  local hour=$(basename "$(pwd)")

  if [ -e "../$hour.mp4" ]; then
    printf "  Skipping hour $hour...\n"
    popd >/dev/null
    return
  fi

  printf "  Processing hour $hour...\n"
  for min in ??.mp4; do
    if [ -e "t$min" ]; then
      printf "    Skipping minute $min...\r"
      continue
    fi
      
    printf "    Processing minute $min...\r"
    _timelapse "$min"
  done

  echo
  local tmplist=.merge
  printf "file '%s'\n" t??.mp4 > "$tmplist"
  $FFMPEG -f concat -safe 0 -i "$tmplist" -c copy \
    "../$hour.mp4"
  rm -f "$tmplist"

  popd >/dev/null
}

_wyze_day() {
  # find "$day" -name "??.mp4" | while read file; do
  local day

  for day; do
    pushd "$day" >/dev/null || exit 1

    echo "Processing day $day..."
    for hour in ??; do
      _wyze_hour "$hour"
    done

    popd >/dev/null
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ "$1" = "-h" ]; then
    shift
    _wyze_hour "$@"
  else
    _wyze_day "$@"
  fi
fi
