#!/usr/bin/env bash

wuuk_auto_on() {
  _patch '{"sourceOnDemand": false}' | jq
}

wuuk_auto_off() {
  _patch '{"sourceOnDemand": true}' | jq
}

_patch() {
  local json=$1
  curl -sS \
    -X PATCH \
    --json "$json" \
    http://localhost:9997/v3/config/paths/patch/wuuk
}

case "$1" in
wuuk-auto-on | wuuk-auto-off)
  cmd=${1//-/_}
  shift
  $cmd
  ;;
*)
  echo "Valid subcommands: wuuk-auto-on | wuuk-auto-off" >&2
  exit 1
  ;;
esac
