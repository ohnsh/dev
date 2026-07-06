get_index() {
  ffmpeg -f avfoundation -list_devices true -i "" 2>&1 |
    grep "$1" |
    sed -E 's/^\[[^]]+\] \[([[:digit:]]+)\].*/\1/g'
}

index=$(get_index "Samson") || {
  echo "Error: couldn't find \"Samson\" mic." >&2
  exit 1
}

echo "Samson G-Track at index $index" >&2

# -c:a libmp3lame -b:a 128k
ffmpeg -hide_banner -v info -f avfoundation -i ":$index" -f segment -segment_time 3600 -strftime 1 "audio_%Y%m%d_%H%M%S.aac"
