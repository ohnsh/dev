#!/usr/bin/env bash

BASE=/Volumes/Media
case "$(pwd)" in
/Volumes/Backup*) BASE=/Volumes/Backup ;;
esac

same_file() {
  local sz1 sz2
  # validation error
  [[ $# -eq 2 && -f $1 && -f $2 ]] || return 1

  sz1=$(stat -f %z "$1")
  sz2=$(stat -f %z "$2")
  [[ $sz1 -eq $sz2 ]] || return 1

  echo "[NOTE] source and destination are same size."
  # assume same file if over 1 MB
  [[ $sz1 -gt 1000000 ]] && return 0

  echo "[NOTE] checking diff..."
  diff -q "$1" "$2"
}

should_skip() {
  local bn=$(basename "$1") dn=$(dirname "$1") bn_alt
  case "$bn" in
  IMG_E*.MOV | IMG_E*.mov)
    bn_alt=IMG_${bn#IMG_E}
    [[ -z $(find "$dn" -iname "${bn_alt%.*}.mov") ]] || return
    ;;
  IMG_*.MOV | IMG_*.mov)
    [[ -z $(find "$dn" -iname "${bn%.*}.heic") ]] || return
    ;;
  esac
  return 1
}

script_path=$(which "$0" || echo "$0")
js_path=$(dirname "$script_path")/parseDate.js

get_dates() {
  local filename_date

  if filename_date=$(deno run "$js_path" "$1"); then
    echo "File:NameDate $(echo "$filename_date" | tr T- " :")"
  fi

  exiftool -a -args -G -AllDates -CreationDate "$1" |
    grep -v =0 |
    sed -e "s/^-//" -e "s/=/ /"
}

compute_path() {
  local IFS=:
  set $@
  dayseg="$1-$2/$3"
}

move() {
  local bn=$(basename "$1") dn=$(dirname "$1")
  local bnE=IMG_E${bn#IMG_} bnO=IMG_O${bn#IMG_}
  local basedir catdir dest destdir to_move

  if lsof "$1" &>/dev/null; then
    echo "Skipping open file: $1" >&2
    return 1
  fi

  case "$bn" in
  IMG_*.* | MMNT_*.*)
    catdir=_15pro
    ;;
  Ring*.mp4 | Ring*.MP4)
    catdir=_sv
    ;;
  memo-* | *.flac | *.wav | *.WAV)
    catdir=_memo
    ;;
  VID_*.mp4 | PRO_VID_*.mp4 | *.insv)
    catdir=_insta360
    ;;
  DJI_*.MP4)
    catdir=_osmo
    ;;
  bug_*.aac | bug_*.opus | bug*.ogg)
    catdir="_bug"
    ;;
  wuuk_*.mp4 | wuuk-patch_*.mp4)
    catdir="_wuuk"
    ;;
  wyze[0-9]_*.mp4 | wyze[0-9]-patch_*.mp4)
    catdir="_${bn%%_*}"
    catdir="${catdir%-patch}"
    ;;
  cam_*.mp4)
    catdir="_cam"
    ;;
  esac

  dn=$(realpath "$dn")
  case "$dn/" in
  */capture/1x1/*)
    catdir=_capture_1x1
    ;;
  */capture/*)
    catdir=_capture_2x2
    ;;
  esac

  if [[ -z $catdir ]]; then
    catdir=_misc
  fi

  basedir=$BASE/days/$dayseg/$catdir
  if [[ -d $basedir ]]; then
    while IFS= read -r dest; do
      if same_file "$1" "$dest"; then
        echo "[NOTE] Skipping $1 -- identical file in destination."
        return
      fi
    done < <(find "$basedir" -name "$bn")
  fi

  to_move=$(
    find -s "$dn" -maxdepth 1 \
      -iname "${bn%.*}.*" -or \
      -iname "${bnE%.*}.*" -or \
      -iname "${bnO%.*}.*"
  )

  if [[ $(echo "$to_move" | wc -l) -gt 2 || -e $basedir/$bn ]]; then
    basedir=$basedir/${bn%.*}
  fi

  seq=0
  destdir=$basedir
  while [[ -e $destdir/$bn ]]; do
    seq=$((seq + 1))
    destdir=${basedir}_$seq
  done

  mkdir -pv "$destdir"
  echo "$to_move" | while IFS= read -r file; do
    mv -nv "$file" "$destdir"
  done
}

process_media() {
  local dates range maxlen date sel

  if [[ ! -e $1 ]]; then
    echo "Error: $1 doesn't exist."
    return 1
  fi

  echo "Processing: $1"

  # First thing's first
  chmod -x "$1"

  if should_skip "$1"; then
    echo "Found alt. Skipping."
    return
  fi

  dates=$(get_dates "$1" | sort -k 2 | sed "/^$/d")
  if [ -z "$dates" ]; then
    echo "No date information. Skipping."
    return
  fi

  if [ -z "$DXIF_SELECT" ]; then
    range=$(printf "[1-%d]" $(echo "$dates" | wc -l))
    maxlen=$(echo "$dates" | cut -w -f1 | wc -L)

    # pretty-print prompt
    # xargs -L1 printf "%-${len}s %-10s %-10s\n"
    echo "$dates" | column -t | nl
    while read -rp "Please select $range (1): " sel; do
      case "${sel:=1}" in $range) break ;;
      esac
    done
  else
    sel=$DXIF_SELECT
  fi

  date=$(echo "$dates" | sed -n ${sel:-1}p | cut -w -f 2)
  compute_path "$date"
  move "$1"
}

handle_dir() {
  while IFS= read -r file; do
    # might have already moved
    [[ -f $file ]] && process_media "$file"
  done < <(find -E -s "$1" \
    -maxdepth 1 -not -iname "img_e*.mov" \
    -iregex ".*\.($_mext)")
  # -or -iname "*.mp4" -or -iname "*.heic"  \
  # -or -iname "*.png" -or -iname "*.jpg" -or -iname "*.jpeg"
}

DXIF_MODE=archive
while [ $# -gt 0 ]; do
  case "$1" in
  archive | tag)
    DXIF_MODE=$1
    shift
    ;;
  -[0-9])
    DXIF_SELECT=${1#-}
    shift
    ;;
  *) break ;;
  esac
done

_mext="jpg|jpeg|png|heic|mov|mp4|m4a|aac|opus|ogg|flac|wav|insv"

if [ "$DXIF_MODE" = archive ]; then
  for arg; do
    if [ -d "$arg" ]; then
      handle_dir "$arg"
    elif echo "$arg" | grep -Eiq ".*\.($_mext)"; then
      [ -f "$arg" ] && process_media "$arg"
    fi
  done
fi
