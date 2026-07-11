#!/usr/bin/env bash

BUGDIR=/recordings
host_bugdir=$HOME/Export/bug

usage() {
  cat <<EOF
Usage: $(basename "$0") [-has] [HOSTNAME]

Options:
  -h    Display this help and exit
  -a    Attach to existing container
  -s    Open shell in existing container

Arguments:
  HOSTNAME    The hostname or IP address of the pulseaudio server. Default: 'mak.local'

Description:
  Continuously record the default source from a pulseaudio server
  to aac or opus files. Default segment length is one hour.

EOF
}

mdns_resolve() {
  local host=$1
  avahi-resolve -4 -n "$host" | cut -f 2
}

mode=start
if [[ $1 == "-h" ]]; then
  usage
  exit 0
elif [[ $1 == "-a" ]]; then
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
  # No mdns resolver available in the container, so we'll pass in the mapping via the
  # command line.
  declare -a host_mapping
  if [[ $host == *.local ]]; then
    host_mapping=(--add-host "$host:$(mdns_resolve "$host")")
  fi

  # run detached but allocate a pty so that ffmpeg's terminal logging
  # looks right if/when we do attach.
  # -i is probably silly but it seemed to help with an issue where
  # the detach key sequence wasn't working.
  docker run -dit \
    --name "$name" \
    --user "$(id -u):$(id -g)" \
    --restart unless-stopped \
    "${host_mapping[@]}" \
    -e "BUGDIR" -e "TZ" \
    -v "$host_bugdir:$BUGDIR" \
    "$image"

elif [[ $mode == attach ]]; then
  # Attach to existing bug.
  docker attach "$name" || docker start -ai "$name"
else
  # Get a bash shell inside existing bug.
  docker start "$name" && docker exec -it "$name" /bin/bash
fi
