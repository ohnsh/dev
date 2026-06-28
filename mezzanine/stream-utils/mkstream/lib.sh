YT_URL=${YT_URL:-rtmp://a.rtmp.youtube.com/live2/$YT_STREAM_KEY}
ffmpeg="ffmpeg -hide_banner"

_ffmpeg() {
  $ffmpeg $RATE_OPTS -i "$1" $CV_OPTS $CA_OPTS -f flv "$YT_URL"
}

_ffmpeg_reencode() {
  $ffmpeg $RATE_OPTS -i "$1" $LIBX264_OPTS $CV_OPTS -c:a copy -f flv "$YT_URL"
}

_ffmpeg_hw_reencode() {
  $ffmpeg $RATE_OPTS -i "$1" $VTBOX_OPTS $CV_OPTS -c:a copy -f flv "$YT_URL"
}

_ffmpeg_copy() {
  $ffmpeg $RATE_OPTS -i "$1" -c:v copy -c:a copy -f flv "$YT_URL"
}

# realtime to emulate stream instead of upload
# RATE_OPTS="-re"
# much more reliable:
RATE_OPTS="-readrate 1 -readrate_catchup 2"
# (see also -readrate_initial_burst (seconds))
# add `-loop 1` to loop indefinitely (uncertain of semantics with playlist)

LIBX264_OPTS="-c:v libx264 -preset veryfast -sc_threshold 0"
VTBOX_OPTS="-c:v h264_videotoolbox -realtime true"
CV_OPTS="-b:v 4500k -maxrate 4500k -bufsize 9000k"
CV_OPTS="$CV_OPTS -g 60 -keyint_min 60"

CA_OPTS="-c:a aac -b:a 128k -ar 44100"

stream_playlist() {
  $ffmpeg $RATE_OPTS \
    -f concat -safe 0 \
    -i <(printf "file '%s'\n" "$@") \
    -c copy -f flv "$YT_URL"
}

LOCAL_URL=rtmp://localhost:12345/live/stream
stream_socket() {
  $ffmpeg -listen 1 -i "$LOCAL_URL" \
    -c:v copy -c:a copy \
    -f flv "$YT_URL"
}

stream_pipe() {
  $ffmpeg -i fifo.flv \
    -c:v copy -c:a copy \
    -f flv "$YT_URL"
}

stream_args() {
  for mp4; do
    $ffmpeg $RATE_OPTS -i "$mp4" -c copy -f mpegts - 2>/dev/null
  done |
    $ffmpeg -f mpegts -i - -c copy -f flv "$YT_URL"
}

stream_folder() {
  files=("$QUEUE_DIR"/*.mp4)

  while true; do
    # If the folder is empty, wait 5 seconds and check again
    if [ ! -e "${files[0]}" ]; then
      echo "Queue empty. Waiting for videos..."
      sleep 5
      continue
    fi
  done
}

_fswatch() {
  fswatch -0 "$WATCH_DIR" | while read -d "" file; do
    # This block triggers instantly only when an .mp4 file changes/closes
    if [ -f "$file" ] && ! lsof "$file" >/dev/null 2>&1; then
      sleep 1
      # Insert your sleep and mv logic here
    fi
  done

  # fswatch --event Updated $DIR | while read file
}
