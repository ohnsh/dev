#!/usr/bin/env bash

default_url=http://localhost:9997/v3
if [[ $(hostname) != box* ]]; then
  default_url=http://box.local:9997/v3
fi
MMTX_API_URL=${MMTX_API_URL:-$default_url}

curl="curl -4"

avail() {
  paths "" | jq '.items[] | select(.available == true) | .name'
}

source_on() {
  local cam=$1
  # case "$cam" in
  # wyze1 | wuuk)
  #   cam=$cam-patch-rec
  #   ;;
  # esac
  _patch "$cam" '{"sourceOnDemand": false}'
}

record_on() {
  local cam=$1
  _patch "$cam" '{"record": true}'
}

record_off() {
  local cam=$1
  _patch "$cam" '{"record": false}'
}

source_off() {
  local cam=$1
  # case "$cam" in
  # wyze1 | wuuk)
  #   cam=$cam-patch-rec
  #   ;;
  # esac
  _patch "$cam" '{"sourceOnDemand": true}'
}

_patch() {
  local cam=$1
  local json=$2
  $curl -sS \
    -X PATCH \
    --json "$json" \
    "$MMTX_API_URL/config/paths/patch/$cam"
}

paths() {
  local path=$1
  if [[ -n $path ]]; then
    $curl -sS "$MMTX_API_URL/paths/get/$path"
  else
    $curl -sS "$MMTX_API_URL/paths/list"
  fi
}

recordings() {
  local path=$1
  if [[ -n $path ]]; then
    $curl -sS "$MMTX_API_URL/recordings/get/$path"
  else
    $curl -sS "$MMTX_API_URL/recordings/list"
  fi
}

config() {
  local path=$1
  if [[ -n $path ]]; then
    $curl -sS "$MMTX_API_URL/config/paths/get/$path" |
      jq 'with_entries(select(.key | startswith("rpiCamera") | not))'
  else
    $curl -sS "$MMTX_API_URL/config/paths/list" |
      jq '.items[] |= with_entries(select(.key | startswith("rpiCamera") | not))'
  fi
}

status() {
  # not exhaustive
  $curl -sS "$MMTX_API_URL/hlssessions/list"
  $curl -sS "$MMTX_API_URL/rtspconns/list"
  $curl -sS "$MMTX_API_URL/rtmpconns/list"
  $curl -sS "$MMTX_API_URL/webrtcsessions/list"
}

cmd=${1//-/_}
shift
if [[ $(type -t "$cmd") == function ]]; then
  $cmd "$@" | jq -r
else
  echo "Valid subcommands:
  config [path]
  paths [path]
  avail
  status
  source-on <path>
  source-off <path>
  record-on <path>
  record-off <path>" >&2
  exit 1
fi
