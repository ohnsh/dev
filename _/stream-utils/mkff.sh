#!/usr/bin/env bash

strobe() {
  local x=8 # default 8x speedup
  if [[ $1 == "-x" ]]; then
    x=$2
    shift 2
  fi

  local in=$1
  shift

  ffmpeg -i "$in" \
    -filter_complex "[0:v]setpts=PTS/$x,fps=30[fast]; $(_strobe_filter)" \
    -map "[v]" -shortest \
    -c:v libx265 -preset fast -tag:v hvc1 \
    "$@"
}

strobe_multi() {
  local x=8 out
  while getopts 'x:o:' opt; do
    case "$opt" in
    x) x=$OPTARG ;;
    o) out=$OPTARG ;;
    \? | :) exit 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  local -a abs_paths
  readarray -t abs_paths < <(realpath "$@")

  local playlist
  playlist=$(_playlist_alt "$@")

  ffmpeg -f concat -safe 0 -i "$playlist" \
    -filter_complex "[0:v]setpts=PTS/$x,fps=30[fast]; $(_strobe_filter)" \
    -map "[v]" -shortest \
    -c:v libx265 -preset fast -tag:v hvc1 \
    "$out"

  rm "$playlist"
}

strobe_hw() {
  local x=8 # default 8x speedup
  if [[ $1 == "-x" ]]; then
    x=$2
    shift 2
  fi

  local in=$1
  shift

  ffmpeg -i "$in" \
    -filter_complex "[0:v]setpts=PTS/$x,fps=30[fast]; $(_strobe_filter)" \
    -map "[v]" -shortest \
    -c:v hevc_videotoolbox -tag:v hvc1 \
    "$@"
}

strobe_vaapi() {
  local x=8 # default 8x speedup
  if [[ $1 == "-x" ]]; then
    x=$2
    shift 2
  fi

  local in=$1
  shift

  ffmpeg \
    -init_hw_device vaapi=gpu:/dev/dri/renderD128 \
    -filter_hw_device gpu \
    -i "$in" \
    -filter_complex "
    [0:v]setpts=PTS/$x,fps=30[fast];
    $(_strobe_filter);
    [v]format=nv12,hwupload[v_hw]" \
    -map "[v_hw]" -shortest \
    -c:v h264_vaapi -qp 25 \
    "$@"
}

# removing audio now, but it would look something like:
# [0:a]atempo=$x.0[a]

_strobe_filter() { cat; } <<EOF
[fast]split=4[tl_raw][tr_raw][bl_raw][br_raw];

[tl_raw]crop=1920:1080:0:0[tl];
[tr_raw]crop=1920:1080:1920:0[tr];
[bl_raw]crop=1920:1080:0:1080,fps=fps=2[bl];
[br_raw]crop=1920:1080:1920:1080,fps=fps=2[br];

[tl][tr][bl][br]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0[v];
EOF

_summary_parse() {
  len=300
  sel=5
  optind=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -l | --length)
      len=$2
      shift 2
      ((optind += 2))
      ;;
    -s | --select)
      sel=$2
      shift 2
      ((optind += 2))
      ;;
    -o | --output)
      out=$2
      shift 2
      ((optind += 2))
      ;;
    *) break ;;
    esac
  done

  if ! [[ $len -gt 0 && $sel -gt 0 ]]; then
    echo "error: --length and --select must be positive integers." >&2
    return 1
  fi
}

summary_select() {
  local len sel optind
  _summary_parse "$@" || return 1
  shift "$optind"

  local in=$1
  shift

  ffmpeg -i "$in" \
    -vf "select='lt(mod(t,$len),$sel)',setpts=N/FRAME_RATE/TB" \
    -af "aselect='lt(mod(t,$len),$sel)',asetpts=N/SR/TB" \
    "$@"
}

summary_select_vaapi() {
  local len sel optind
  _summary_parse "$@" || return 1
  shift "$optind"

  local in=$1
  shift

  ffmpeg \
    -init_hw_device vaapi=gpu:/dev/dri/renderD128 \
    -filter_hw_device gpu \
    -hwaccel vaapi -hwaccel_device gpu -hwaccel_output_format vaapi \
    -i "$in" \
    -vf "select='lt(mod(t,$len),$sel)',setpts=N/FRAME_RATE/TB" \
    -af "aselect='lt(mod(t,$len),$sel)',asetpts=N/SR/TB" \
    -c:v hevc_vaapi -qp 25 -tag:v hvc1 \
    -map 0:v -map 0:a:0 \
    "$@"
}

_duration() {
  ffprobe -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$1"
}

summary_inseek() {
  local len sel optind
  _summary_parse "$@" || return 1
  shift "$optind"

  local in=$1
  shift

  local duration
  duration=$(_duration "$in")
  duration=${duration%%.*}

  local t_start=0 outfile
  local bn=${in##*/}
  local ext=${bn##*.}
  mkdir -p out-segments

  while [[ $t_start -lt $duration ]]; do
    echo loop iter
    outfile="out-segments/${bn%.*}-$t_start.$ext"
    ffmpeg -ss "$t_start" -i "$in" -c copy -t "$sel" "$outfile"
    ((t_start += len))
  done

  local playlist
  playlist=$(_playlist_alt out-segments/*)

  ffmpeg -f concat -safe 0 \
    -i "$playlist" \
    -c:v libx265 \
    -c:a aac \
    -tag:v hvc1 \
    "$@"

  rm "$playlist"
}

summary_segment() {
  local len sel optind
  _summary_parse "$@" || return 1
  shift "$optind"

  local in=$1
  shift

  local times duration t=0
  duration=$(_duration "$in")
  duration=${duration%%.*}

  while [[ $t -lt $duration ]]; do
    times=$times,$t
    [[ $((t + sel)) -lt $duration ]] || break
    times=$times,$((t + sel))
    ((t += len))
  done
  times=${times#,0,}

  local dir=out_segments
  rm -rf "$dir"
  mkdir -p "$dir"

  ffmpeg -i "$in" -f segment -segment_times "$times" -reset_timestamps 1 -c copy "$dir/%03d.mp4"

  rm "$dir"/*{1,3,5,7,9}.*

  local playlist
  playlist=$(_playlist_alt "$dir"/*)

  ffmpeg -f concat -safe 0 -i "$playlist" -c copy "$@"
  rm "$playlist"
}

_playlist() {
  local -a abs_paths
  readarray -t abs_paths < <(realpath -- "$@")
  printf "file '%s'\n" "${abs_paths[@]}"
}

# In ffmpeg concat demuxer playlists, paths are relative to the playlist file, not the
# current directory. When using process substitution to generate the list, the base
# directory is /dev/fd, meaning all the paths must be absolute (which requires the `-safe
# 0` option). Instead, I'm starting to prefer generating a temporary file in the current
# directory. That said, it's not particularly elegant, and stopping an encode with SIGINT
# will probably leave temp files around, so I'm on the fence.
_playlist_alt() {
  local tmp
  tmp=$(mktemp -p .)
  printf "file '%s'\n" "$@" >"$tmp"
  echo "$tmp"
}

summary_segment_multi() {
  local len sel optind out
  _summary_parse "$@" || return 1
  shift "$optind"

  local times duration=0 increment t=0
  for in_file; do
    increment=$(_duration "$in_file")
    increment=${increment%%.*}
    duration=$((duration + increment))
  done

  while [[ $t -lt $duration ]]; do
    times=$times,$t
    [[ $((t + sel)) -lt $duration ]] || break
    times=$times,$((t + sel))
    ((t += len))
  done
  times=${times#,0,}

  local dir=out_segments
  rm -rf "$dir"
  mkdir -p "$dir"

  ffmpeg -f concat -safe 0 -i <(_playlist "$@") -f segment -segment_times "$times" -reset_timestamps 1 -c copy "$dir/%03d.mp4"

  rm "$dir"/*{1,3,5,7,9}.*

  ffmpeg -f concat -safe 0 -i <(_playlist "$dir"/*) -c copy "$out"
}

# default crf: 23 (libx264), 28 (libx265)
# `-preset` trades off speed and file size, quality remains constant
# slow, medium, fast, veryfast
# optional audio stream (no error if absent):
# `-map 0:a?`

_mkff_main() {
  if [[ $(type -t "$1") == "function" ]]; then
    cmd=$1 && shift
    $cmd "$@"
  else
    cat >&2 <<EOF

subcommands:

  strobe, strobe_hw, strobe_vaapi,

  summary_select, summary_select_vaapi, summary_inseek, summary_segment

EOF

    exit 1
  fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  _mkff_main "$@"
fi
