#!/usr/bin/env bash

BUGDIR=/recordings
host_bugdir=$HOME/Export/bug

mdns_resolve() {
  avahi-resolve -4 -n "$1" | cut -f 2
}

_main() {
  docker run -dit \
    --name "$name" \
    --user "$(id -u):$(id -g)" \
    --restart unless-stopped \
    --add-host "$host:$(mdns_resolve "$host")" \
    -e "BUGDIR=$BUGDIR" \
    -v "$host_bugdir:$BUGDIR" \
    "$image"
}

mode=start
if [[ $1 == "-a" ]]; then
  mode=attach
  shift
elif [[ $1 == "-s" ]]; then
  mode=shell
  shift
fi

host=${1:-mak.local}
image=bug
name=bug
mkdir -p "$host_bugdir"

if [[ $mode == start ]]; then
  _main
elif [[ $mode == attach ]]; then
  docker attach "$name" || docker start -ai "$name"
else
  docker start "$name" && docker exec -it "$name" /bin/bash
fi
