#!/usr/bin/env bash

script_dir=$(dirname "$0")

new() {
  if ! tmux has-session -t stream 2>/dev/null; then
    exec tmux new-session \
      -s stream \
      -e "STATUS_FIFO=$PWD/status.fifo" \
      './monitor.sh <>"$STATUS_FIFO"' \
      \; new-win \
      \; split-win -h -d
  fi
  exec tmux attach -t stream
}

record() {
  local cam=$1
  "$script_dir/cam.sh" record localhost "$cam"
}

stream() {
  "$script_dir/stream_folder.sh" "$HOME/Export/cam" "$HOME/export/cam_out"
}

cmd=${1:-new}
shift

case "$cmd" in
new | record | stream)
  $cmd "$@"
  ;;
*)
  echo "Invalid subcommand '$cmd'" >&2
  exit 1
  ;;
esac
