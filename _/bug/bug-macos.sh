#!/usr/bin/env bash

outdir=/Users/jms/Downloads/bug
mic="Samson G-Track Pro"

get_index() {
  ffmpeg -f avfoundation -list_devices true -i "" 2>&1 |
    grep "$1" |
    sed -E 's/^\[[^]]+\] \[([[:digit:]]+)\].*/\1/g'
}

bug_ffmpeg() {
  local index
  index=$(get_index "$mic") || {
    echo "Error: couldn't find device: \"$mic\"" >&2
    exit 1
  }

  echo "$mic at index $index" >&2

  # -c:a libmp3lame -b:a 128k
  /usr/bin/caffeinate -s /opt/homebrew/bin/ffmpeg -hide_banner \
    -f avfoundation -i ":$index" \
    -ar 48000 -ac 2 -f segment -segment_time 3600 \
    -strftime 1 "$outdir/bug_%Y%m%d_%H%M%S.aac"
}

# I can't get rid of a crackling artifact in ffmpeg audio recordings.
# sox_ng does much better.
bug_sox() {
  local rec=/opt/homebrew/opt/sox_ng/bin/rec
  local len_s=3600
  local last_time=0 now elapsed
  local min_elapsed=10
  local name
  local status

  while true; do
    now=$(date +%s)
    elapsed=$((now - last_time))
    if [[ $elapsed -lt $min_elapsed ]]; then
      echo "Error detected: fast loop iteration. Exiting." >&2
      exit 1
    fi
    last_time=$now
    name=bug_$(date +%Y%m%d_%H%M%S).ogg
    # see -C for quality factor
    $rec -t coreaudio "$mic" "$outdir/$name" trim 0 "$len_s" || {
      status=$?
      echo "Error detected: sox_ng exited with non-zero status. Exiting." >&2
      exit $status
    }
  done
}

clean_wav() {
  # for uncompressed (flac or wav) recordings on macOS
  # (afconvert uses aac hardware encoder)
  afconvert -f m4af -d aac -b 160000 -q 127 -s 2 "$1" "${1%.wav}.m4a" && rm "$1"
}

mkdir -p "$outdir"
bug_sox
