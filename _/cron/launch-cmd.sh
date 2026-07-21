#!/usr/bin/env bash

service=com.user.daily
script=$HOME/Library/LaunchAgents/${service}.plist
d=gui/$(id -u)

install() {
  if [[ ! -f $script ]]; then
    cp "$PWD/${service}.plist" "$script"
    chmod 0644 "$script"
  fi

  load
}

load() {
  launchctl bootstrap "$d" "$script"
}

unload() {
  launchctl bootout "$d" "$script"
}

list() {
  launchctl list | grep com\\.user
}

kickstart() {
  launchctl kickstart -k "$d/$service"
}

misc() {
  # 1. Start the container in detached mode and save its ID
  CONTAINER_ID=$(docker run -d your-container-image)

  # 2. Tell caffeinate to keep the Mac awake until that container exits
  caffeinate -s docker wait "$CONTAINER_ID"
}

cmd=$1
shift

case "$cmd" in
load | unload | install | list | kickstart)
  $cmd "$@"
  ;;
*)
  echo "Invalid subcommand '$cmd'" >&2
  exit 1
  ;;
esac
