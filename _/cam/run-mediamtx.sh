#!/usr/bin/env bash

CAM_USER=thingino
CAM_PASS=thingino
CAM_HOST=ing-wuuk.local
CAM_IP=$(getent hosts "$CAM_HOST" | awk '{ print $1 }')
CAM_SOURCE=rtsp://$CAM_USER:$CAM_PASS@$CAM_HOST:554/ch0

docker run -dit \
  --restart unless-stopped \
  -e MTX_RTSPTRANSPORTS=tcp \
  -e MTX_PATHS_WUUK_SOURCE="$CAM_SOURCE" \
  -p 8554:8554 \
  -p 1935:1935 \
  -p 8888:8888 \
  -p 8889:8889 \
  -p 8890:8890/udp \
  -p 8189:8189/udp \
  -v ./mediamtx.yml:/mediamtx.yml:ro \
  --add-host "$CAM_HOST:$CAM_IP" \
  --name cam-mmtx \
  cam-mmtx

  # bluenviron/mediamtx:1
  # -e MTX_WEBRTCADDITIONALHOSTS=192.168.x.x \
