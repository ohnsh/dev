#!/usr/bin/env bash

script_dir=$(dirname "$0")
if [[ ! -f $script_dir/timelapse.sh ]]; then
  echo "Required script $script_dir/timelapse.sh not found. Exiting." >&2
  exit 1
fi
. "$script_dir/timelapse.sh"

ffmpeg="ffmpeg -v warning -y"

if ffmpeg -v error -encoders | grep -q hevc_videotoolbox; then
  echo "Apple Silicon detected; using hevc_videotoolbox encoder." >&2
  timelapse=timelapse_vtb
elif ffmpeg -v error -encoders | grep -q hevc_vaapi; then
  echo "Intel VAAPI platform detected; using hevc_vaapi encoder." >&2
  timelapse=timelapse_vaapi
else
  echo "No hardware acceleration detected; using default libx265 encoder." >&2
  timelapse=timelapse_libx265
fi

_wyze_hour() {
  local _hour=$1 min hour
  pushd "$_hour" >/dev/null || exit 1
  hour=$(basename "$(pwd)")

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
    $timelapse "$min"
  done

  echo
  $ffmpeg -f concat -safe 0 -i <(printf "file '%s'\n" t??.mp4) -c copy \
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

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  if [[ $1 == "-h" ]]; then
    shift
    _wyze_hour "$@"
  else
    _wyze_day "$@"
  fi
fi
