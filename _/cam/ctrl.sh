#!/usr/bin/env bash

base_url=http://localhost:9997/v3

wuuk_auto_on() {
  _patch '{"sourceOnDemand": false}'
}

wuuk_auto_off() {
  _patch '{"sourceOnDemand": true}'
}

_patch() {
  local json=$1
  curl -sS \
    -X PATCH \
    --json "$json" \
    $base_url/config/paths/patch/wuuk
}

paths() {
  local path=$1
  if [[ -n $path ]]; then
    curl -sS "$base_url/paths/get/$path"
  else
    curl -sS $base_url/paths/list
  fi
}

config() {
  local path=$1
  if [[ -n $path ]]; then
    curl -sS "$base_url/config/paths/get/$path" |
      jq 'with_entries(select(.key | startswith("rpiCamera") | not))'
  else
    curl -sS $base_url/config/paths/list |
      jq '.items[] |= with_entries(select(.key | startswith("rpiCamera") | not))'
  fi
}

status() {
  # not exhaustive
  curl -sS $base_url/hlssessions/list
  curl -sS $base_url/rtspconns/list
  curl -sS $base_url/rtmpconns/list
  curl -sS $base_url/webrtcsessions/list
}

cmd=${1//-/_}
shift
if [[ $(type -t "$cmd") == function ]]; then
  $cmd "$@" | jq
else
  echo "Valid subcommands:
  config [path]
  paths [path]
  status
  wuuk-auto-on
  wuuk-auto-off" >&2
  exit 1
fi
