#!/usr/bin/env bash

. .env
. lib.sh

stream_mmtx() {
    YT_URL=rtmp://localhost/yt-fwd stream_args "$@"
}

if [ "$(type -t "$1")" = "function" ]; then
    fn=$1
    shift
    $fn "$@"
fi
