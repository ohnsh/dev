#!/usr/bin/env bash

script_dir=$(dirname "${BASH_SOURCE[0]}")
. "$script_dir/lib.sh"

test_audio() {
  ffprobe -v quiet \
    -select_streams a \
    -show_entries stream=codec_type \
    -of default=noprint_wrappers=1 \
    "$@"
}

# FFmpeg docs:
# Make sure to require a closed GOP when encoding and to set the GOP size to fit your
# segment time constraint.
# ffmpeg -i in.mkv -c:v h264 -flags +cgop -g 30 -hls_time 1 out.m3u8
#
# +cgop is libavcodec-specific. For hevc_videotoolbox, Gemini suggests `-forced-idr 1`
#
# In any case, segment duration and GOP must agree (segment duration should be a multiple
# of GOP/framerate)

check_opts() {
  if ! declare -p out_dir in_opts audio_opts gop seg_length _720p &>/dev/null; then
    echo "$1: out_dir, in_opts, audio_opts, gop, seg_length, and _720p must be set by caller and in-scope" >&2
    return 1
  fi
}

hls_vaapi() {
  check_opts "hls_vaapi" || exit 1
  # -rc_mode CQP -qp [1-51] # 20-23: excellent; 24-26: baseline
  # -rc_mode VBR -b:v 4M -maxrate:v 5M -bufsize:v 10M
  ffmpeg -v warning \
    -vaapi_device /dev/dri/renderD128 \
    -hwaccel vaapi \
    -hwaccel_output_format vaapi \
    "${in_opts[@]}" \
    -vf "scale_vaapi=$_720p" \
    -c:v hevc_vaapi \
    "${audio_opts[@]}" \
    -tag:v hvc1 \
    -g "$gop" \
    -hls_time "$seg_length" \
    -hls_playlist_type vod \
    -hls_segment_type fmp4 \
    -hls_segment_filename "$out_dir/seg_%03d.m4s" \
    -f hls "$out_dir/index.m3u8"
}

hls_vtb() {
  check_opts "hls_vtb" || exit 1
  # local q_opts=(-q:v 60)
  # local q_opts=(-b:v 1M)
  ffmpeg -v warning \
    -hwaccel videotoolbox \
    -hwaccel_output_format videotoolbox_vld \
    "${in_opts[@]}" \
    -vf "scale_vt=$_720p" \
    -c:v hevc_videotoolbox \
    "${audio_opts[@]}" \
    -tag:v hvc1 \
    -g "$gop" \
    -hls_time "$seg_length" \
    -hls_playlist_type vod \
    -hls_segment_type fmp4 \
    -hls_segment_filename "$out_dir/seg_%03d.m4s" \
    -f hls "$out_dir/index.m3u8"
}

hls_xcode_hw_hevc() {
  local _outdir="$outdir/720p-hevc"
  mkdir -p "$_outdir"
  $ffmpeg -hwaccel videotoolbox -i "$1" \
    -vf "scale=$_720p" \
    -c:v hevc_videotoolbox -b:v 4M -maxrate:v 6M -bufsize:v 8M \
    -tag:v hvc1 \
    -c:a aac -b:a 128k -ac 2 \
    -hls_time 6 \
    -hls_playlist_type vod \
    -hls_segment_type fmp4 \
    -hls_segment_filename "$_outdir/seg_%03d.m4s" \
    -f hls "$_outdir/playlist.m3u8"
}

hls_libx265() {
  echo "hls_libx265: UNIMPLEMENTED" >&2
  exit 1
}

hw_detect() {
  if ffmpeg -v error -encoders | grep -q hevc_videotoolbox; then
    echo "Apple Silicon detected; using hevc_videotoolbox encoder." >&2
    hls=hls_vtb
  elif ffmpeg -v error -encoders | grep -q hevc_vaapi; then
    echo "Intel VAAPI platform detected; using hevc_vaapi encoder." >&2
    hls=hls_vaapi
  else
    echo "No hardware acceleration detected; using default libx265 encoder." >&2
    hls=hls_libx265
  fi
}

pre_process() {
  if [ -n "$PORTRAIT" ]; then
    _1080p=1080:-2
    _720p=720:-2
    _480p=480:-2
  else
    _1080p=-2:1080
    _720p=-2:720
    _480p=-2:480
  fi
}

concat() {
  local pl out_dir count

  while [[ $1 == -? ]]; do
    case "$1" in
    -o)
      out_dir=$2
      shift 2
      ;;
    -n)
      count=$2
      shift 2
      ;;
    *)
      echo "usage: $0 concat -o OUT_DIR [FILES...|IN_DIR]" >&2
      exit 1
      ;;
    esac
  done

  if [[ -z $out_dir ]]; then
    echo "usage: $0 concat -o OUT_DIR [FILES...|IN_DIR]" >&2
    exit 1
  fi
  out_dir=${out_dir%/}

  if [[ $# -eq 1 && -d "$1" ]]; then
    local files=("$1"/*)
    local first=${files[0]}

    if [[ ! -f "$first" ]]; then
      echo "error: $first doesn't exist." >&2
      exit 1
    fi

    if ! probe_vid "$first"; then
      echo "error: $first doesn't appear to be a video." >&2
      exit 1
    fi

    echo "using video parameters from $(basename "$first") $(get_stats)" >&2
    pre_process

    local fr=${FRAME_RATE%/*}
    local seg_length=2
    local gop=$((fr * seg_length))
    echo "concat: using calculated GOP of $gop frames (${seg_length}s @ $fr fps)" >&2

    local audio_opts=()
    if test_audio "$first" | grep audio; then
      audio_opts=(-c:a aac -b:a 128k -ac 2)
    else
      echo "concat: no audio detected" >&2
    fi

    # list the first $count files, defaulting to all if $count is empty
    pl=$(_playlist "${files[@]:0:${count:-${#files[@]}}}")

    local in_opts=(-f concat -safe 0 -i "$pl")
    # out_dir=$out_dir/$(basename "$first").hls
    out_dir=${out_dir}/720p-hevc
    mkdir -p "$out_dir"

    hw_detect
    $hls
  else
    pl=$(_playlist "$@")
  fi

  if [[ -f "$pl" ]]; then
    rm -f "$pl"
  fi
}

# alternate implementation, letting `mktemp` choose the name
_playlist() {
  local tmp
  tmp=$(mktemp -p .)
  printf "file '%s'\n" "$@" >"$tmp"
  echo "$tmp"
}

pltmp=.playlist.txt
mk_playlist() {
  printf "file '%s'\n" "$@" >"$pltmp"
  echo "$pltmp"
}

rm_playlist() {
  if [[ -f "$pltmp" ]]; then
    rm -f "$pltmp"
  fi
}

cmd=$1
shift

case "$cmd" in
concat)
  concat "$@"
  ;;
test-audio)
  test_audio "$@"
  ;;
vaapi)
  for file; do
    if ! [ -f "$file" ]; then
      echo "error: skipping non-file $file" >&2
      continue
    elif ! probe_vid "$file"; then
      echo "error: skipping non-video file $file" >&2
      continue
    fi

    echo "processing video $file $(get_stats)" >&2

    outdir=$(get_outdir "$file")/hls
    mkdir -p "$outdir"

    pre_process &&
      $CMD "$file"
  done
  ;;
*)
  echo "Invalid subcommand: $cmd" >&2
  exit 1
  ;;
esac
