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
# +cgop is libavcodec-specific. For hevc_videotoolbox, Gemini suggests (with `-forced-idr`
# being critical):
#
# ffmpeg -i input.mp4 \
# -c:v hevc_videotoolbox \
# -g 60 \
# -forced-idr 1 \
# -f hls -hls_time 2 -hls_playlist_type vod output.m3u8
#
# For hevc_vaapi:
#
# ffmpeg -vaapi_device /dev/dri/renderD128 -i input.mp4 \
# -vf "format=nv12,hwupload" \
# -c:v hevc_vaapi \
# -g 60 -keyint_min 60 \
# -sc_threshold 0 \
# -f hls -hls_time 2 -hls_playlist_type vod output.m3u8
#
# In any case, segment duration and GOP must agree (segment duration should be a multiple
# of GOP/framerate)

hls_vaapi() {
  if ! declare -p out_dir in_opts has_audio FRAME_RATE _720p &>/dev/null; then
    echo "hls_vaapi: out_dir, in_opts, has_audio, FRAME_RATE, and _720p must be set by caller and in-scope" >&2
    return 1
  fi

  local fr=${FRAME_RATE%/*}
  local seg_length=2
  local gop=$((fr * seg_length))
  echo "hls_vaapi: using calculated GOP of $gop frames (${seg_length}s @ $fr fps)" >&2

  [[ -z $has_audio ]] && echo "hls_vaapi: no audio detected" >&2

  local sub_dir=720p-hevc
  mkdir -p "$out_dir/$sub_dir"

  # -rc_mode CQP -qp [1-51] # 20-23: excellent; 24-26: baseline
  # -rc_mode VBR -b:v 4M -maxrate:v 5M -bufsize:v 10M
  ffmpeg -v warning \
    -vaapi_device /dev/dri/renderD128 \
    -hwaccel vaapi \
    -hwaccel_output_format vaapi \
    "${in_opts[@]}" \
    -vf "scale_vaapi=$_720p" \
    -c:v hevc_vaapi \
    ${has_audio:+-c:a aac -b:a 128k -ac 2} \
    -tag:v hvc1 \
    -g "$gop" \
    -hls_time "$seg_length" \
    -hls_playlist_type vod \
    -hls_segment_type fmp4 \
    -hls_segment_filename "$out_dir/$sub_dir/seg_%03d.m4s" \
    -f hls "$out_dir/$sub_dir/index.m3u8"
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
  local pl first out_dir has_audio
  local -a files in_opts

  if [[ $1 != '-o' ]]; then
    echo "usage: $0 concat -o OUT_DIR [FILES...|IN_DIR]" >&2
    exit 1
  fi

  out_dir=${2%/}
  shift 2

  if [[ $# -eq 1 && -d "$1" ]]; then
    files=("$1"/*)
    first=$files

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

    pl=$(_playlist "${files[@]}")

    if test_audio "$first" | grep audio; then
      has_audio=1
    fi
    in_opts=(-f concat -safe 0 -i "$pl")
    out_dir=$out_dir/$(basename "$first").hls
    mkdir -p "$out_dir"

    hls_vaapi
  else
    pl=$(_playlist "$@")
  fi

  [[ -f "$pl" ]] && rm -f "$pl"
}

_playlist() {
  local tmp
  tmp=$(mktemp -p .)
  printf "file '%s'\n" "$@" >"$tmp"
  echo "$tmp"
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
