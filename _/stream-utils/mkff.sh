#!/usr/bin/env bash

# works great for creating the type of timelapse videos I was making
# in Final Cut a few months ago.
strobe() {
  x=8 # default 8x speedup
  if [[ $1 == "-x" ]]; then
    x=$2
    shift 2
  fi

  in=$1
  shift

  ffmpeg -i "$in" \
    -filter_complex "$(_strobe_filter "$x")" \
    -map "[v]" -map "[a]" \
    -c:v libx265 -preset fast -tag:v hvc1 -shortest "$@"
}

strobe_opt() {
  local in=$1
  shift

  ffmpeg -i "$in" \
    -filter_complex "[0:v]setpts=PTS/10,fps=30[fast]; $(_strobe_filter_opt)" \
    -map "[v]" \
    -c:v libx265 -preset fast -tag:v hvc1 \
    -shortest "$@"
}

strobe_hw() {
  x=8 # default 8x speedup
  if [[ $1 == "-x" ]]; then
    x=$2
    shift 2
  fi

  in=$1
  shift

  ffmpeg -i "$in" \
    -filter_complex "$(_strobe_filter "$x")" \
    -map "[v]" -map "[a]" \
    -c:v hevc_videotoolbox -tag:v hvc1 -shortest "$@"
}

strobe_vaapi() {
  x=8 # default 8x speedup
  if [[ $1 == "-x" ]]; then
    x=$2
    shift 2
  fi

  in=$1
  shift

  ffmpeg \
    -init_hw_device vaapi=gpu:/dev/dri/renderD128 \
    -filter_hw_device gpu \
    -i "$in" \
    -filter_complex "$(_strobe_filter "$x"); [v]format=nv12,hwupload[v_hw]" \
    -c:v h264_vaapi -qp 25 \
    -map "[v_hw]" -map "[a]" -shortest \
    "$@"
}

_strobe_filter() {
  local x=$1

  cat <<EOF
[0:v]setpts=PTS/$x,split=4[tl_raw][tr_raw][bl_raw][br_raw];

[tl_raw]crop=1920:1080:0:0[tl];
[tr_raw]crop=1920:1080:1920:0[tr];
[bl_raw]crop=1920:1080:0:1080,fps=fps=2[bl];
[br_raw]crop=1920:1080:1920:1080,fps=fps=2[br];

[tl][tr][bl][br]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0[v];
[0:a]atempo=$x.0[a]
EOF
}

_strobe_filter_opt() { cat; } <<EOF
[fast]split=4[tl_raw][tr_raw][bl_raw][br_raw];

[tl_raw]crop=1920:1080:0:0[tl];
[tr_raw]crop=1920:1080:1920:0[tr];
[bl_raw]crop=1920:1080:0:1080,fps=fps=2[bl];
[br_raw]crop=1920:1080:1920:1080,fps=fps=2[br];

[tl][tr][bl][br]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0[v];
EOF

_segment_parse() {
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
    *) break ;;
    esac
  done

  if ! [[ $len -gt 0 && $sel -gt 0 ]]; then
    echo "error: --length and --select must be positive integers." >&2
    return 1
  fi
}

segment() {
  local len sel optind
  _segment_parse "$@" || return 1
  shift "$optind"

  local in=$1
  shift

  ffmpeg -i "$in" \
    -vf "select='lt(mod(t,$len),$sel)',setpts=N/FRAME_RATE/TB" \
    -af "aselect='lt(mod(t,$len),$sel)',asetpts=N/SR/TB" \
    "$@"
}

segment_vaapi() {
  local len sel optind
  _segment_parse "$@" || return 1
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

get_duration() {
  ffprobe -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$1"
}

segment_stitch() {
  local len sel optind
  _segment_parse "$@" || return 1
  shift "$optind"

  local in=$1
  shift

  local duration
  duration=$(get_duration "$in")
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

  ffmpeg -f concat -safe 0 -i <(printf "file '%s'\n" "$PWD"/out-segments/*) -c:v libx265 -c:a aac -tag:v hvc1 "$@"
}

segment_stitch_improved() {
  local len sel optind
  _segment_parse "$@" || return 1
  shift "$optind"

  local in=$1
  shift

  local times
  local t=0
  local duration
  duration=$(get_duration "$in")
  duration=${duration%%.*}

  while [[ $t -lt $duration ]]; do
    times=$times,$t
    [[ $((t + sel)) -lt $duration ]] || break
    times=$times,$((t + sel))
    ((t += len))
  done
  times=${times#,0,}

  rm -rf out-segments
  mkdir -p out-segments

  ffmpeg -i "$in" -f segment -segment_times "$times" -reset_timestamps 1 -c copy out-segments/%03d.mp4

  rm out-segments/*{1,3,5,7,9}.*

  ffmpeg -f concat -safe 0 -i <(printf "file '%s'\n" "$PWD"/out-segments/*) -c copy "$@"
}

# default crf: 23 (libx264), 28 (libx265)
# `-preset` trades off speed and file size, quality remains constant
# slow, medium, fast, veryfast
# optional audio stream (no error if absent):
# `-map 0:a?`
