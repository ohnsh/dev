#!/usr/bin/env bash

script_dir=${BASH_SOURCE[0]%/*}
[ -f "$script_dir"/.env ] && . "$script_dir"/.env

YT_URL=rtmp://a.rtmp.youtube.com/live2/$YT_STREAM_KEY

relay_rtsp() {
  local host=${1:-"ing-wuuk.local"}
  local addr rtsp

  addr=$(avahi-resolve -4 -n "$host" | cut -f 2)

  if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ -z "$addr" ]]; then
    echo "Error resolving host: $host" >&2
    return 1
  fi

  rtsp=rtsp://thingino:thingino@$addr/ch0
  ffmpeg -i "$rtsp" -c copy -f flv "$YT_URL"
}

buffer() {
  ffmpeg \
    -c copy \
    -f segment -segment_time 60 \
    -strftime 1 "stream_buffer/%Y-%m-%d_%H-%M-%S.ts"
}

relay_rtsp "$@"
