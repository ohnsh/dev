#!/usr/bin/env bash

mdns_resolve() {
  local host=$1
  if command -v avahi-resolve &>/dev/null; then
    avahi-resolve -4 -n "$host" | awk '{ print $2 }'
  else
    getent hosts "$host" | awk '{ print $1 }'
  fi
}

CAM_USER=thingino
CAM_PASS=thingino
CAM_HOST=${CAM_HOST:-ing-wuuk.local}

host_mapping=()
if [[ $CAM_HOST == *.local ]]; then
  CAM_IP=$(mdns_resolve "$CAM_HOST") || {
    echo "Error resolving mdns name $CAM_HOST. (Is avahi-resolve installed?)" >&2
    exit 1
  }
  host_mapping=(--add-host "$CAM_HOST:$CAM_IP")
fi

CAM_SOURCE=rtsp://$CAM_USER:$CAM_PASS@$CAM_HOST:554/ch0

if [[ -d $HOME/Export ]]; then
  RECORDINGS_HOST=$HOME/Export/cam
else
  RECORDINGS_HOST=$PWD/recordings
fi
# prevent docker from creating directory with root ownership
mkdir -p "$RECORDINGS_HOST"

run() {
  docker run -dit \
    --name cam-proxy \
    --restart unless-stopped \
    --user "$(id -u):$(id -g)" \
    --network host \
    -e "TZ" \
    -e MTX_RTSPTRANSPORTS=tcp \
    -e MTX_PATHS_WUUK_SOURCE="$CAM_SOURCE" \
    -v ./mediamtx.yml:/mediamtx.yml:ro \
    -v "$RECORDINGS_HOST:/recordings" \
    "${host_mapping[@]}" \
    cam-proxy

    # -p 8554:8554 \
    # -p 1935:1935 \
    # -p 8888:8888 \
    # -p 8889:8889 \
    # -p 8890:8890/udp \
    # -p 8189:8189/udp \
    # -p 9997:9997 \
  # bluenviron/mediamtx:latest-ffmpeg
  # -e MTX_WEBRTCADDITIONALHOSTS=192.168.x.x \
}

build() {
  docker build -t cam-proxy .
}

cmd=run
case "$1" in
run | build)
  cmd=$1
  shift
  ;;
esac

$cmd
