#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/.env"
. "$SCRIPT_DIR/lib.sh"

stream_mmtx() {
    YT_URL=rtmp://localhost/yt-fwd stream_args "$@"
}

if [ "$(type -t "$1")" = "function" ]; then
    fn=$1
    shift
    $fn "$@"
fi
