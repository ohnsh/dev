#!/usr/bin/env bash

wav_to_aac() {
  bn=$(basename "$1")
  # using Apple's Core Audio interface afconvert
  afconvert -f m4af -d aac -b 224000 "$wav" afconvert/${bn%.*}.m4a
  # using ffmpeg
  # ffmpeg -i "$wav" -c:a aac -b:a 196k aac/${bn%.*}.m4a
}

dji_shorten() {
  for dji; do
    [ -e "$dji" ] || continue
    bn=$(basename "$dji")
    dn=$(dirname "$dji")
    case "$bn" in
    DJI_??_*)
      bn_s=DJI_${bn#DJI_??_}
      mv -nv "$dji" "$dn/$bn_s"
      ;;
    esac
  done
}

ffplay_meter() {
  # list devices:
  # ffmpeg -f avfoundation -list_devices true -i ""
  ffplay -f avfoundation -i ":0" -vf "showvolume=w=600:h=40:f=0.5"
}

ring_rename() {
  # TODO: auto-detect DST

  exiftool '-quicktime:createdate<filename' -overwrite_original "$1" &&
    exiftool -globaltimeshift "-5:00" \
      -d "Ring_%Y%m%d_%H%M%%-c.%%e" \
      '-filename<createdate' "$1"
}

wav_to_flac() {
  if [ -d "$1" ]; then
    set -- "$1"/*.wav "$1"/*.WAV
  fi

  for wav; do
    [ -e "$wav" ] || continue
    ffmpeg -hide_banner -v warning -i "$wav" "${wav%.*}.flac"
  done
}

mov_to_mp4() {
  mp4=${1%.*}.mp4

  ffmpeg -i "$1" -c copy "$mp4"
  exiftool -tagsfromfile "$1" -all:all "$mp4"
}

extract_ring_timestamp() {
  ffmpeg -hide_banner -loglevel quiet -y -i "$1" -frames:v 1 -filter:v crop=x=1630:y=1020:w=290:h=60 "${1%.*}.png"

  part1=${1%%_*}
  part2=${1##*_}
  ocrdate=$(ringdate.js "$(ocrs out.png)")

  if [ $? -neq 0 ]; then
    echo "[$1] Invalid OCR reading: $ocrdate"
    exit 1
  fi

  fname=${part1}_approx_${ocrdate}_${part2}
  mv "$1" "$fname"

}

_realpath() {
  # copilot.ai knocking it out of the park
  #

  [ $# -eq 1 ] || exit 1

  if command -v realpath >/dev/null 2>&1; then
    canonical_path=$(realpath "$1")
  elif command -v readlink >/dev/null 2>&1; then
    canonical_path=$(readlink -f "$1")
  else
    canonical_path="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  fi

  retval=$?
  [ $retval -eq 0 ] || exit $retval

  echo "$canonical_path"
}

fixif() {
  if [ "$1" = "-n" ]; then
    shift
  else
    exiftool -all:all= "$1"
  fi

  exiftool -tagsfromfile "$2" -all:all "$1"
}
