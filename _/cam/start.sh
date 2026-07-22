#!/usr/bin/env bash

script_dir=$(dirname "$0")
STATUS_FIFO=${STATUS_FIFO:-$PWD/status.fifo}

new() {
  if ! tmux has-session -t stream 2>/dev/null; then
    [[ -f $STATUS_FIFO ]] || mkfifo "$STATUS_FIFO"
    # important to set env this way because it's inherited from the tmux server, not the
    # current shell.
    exec tmux new-session \
      -s stream \
      -e "STATUS_FIFO=$STATUS_FIFO" \
      ${STREAM_DIR:+-e STREAM_DIR="$STREAM_DIR"} \
      ${STREAM_ARCHIVE_DIR:+-e STREAM_ARCHIVE_DIR="$STREAM_ARCHIVE_DIR"} \
      "./monitor.sh <>\"\$STATUS_FIFO\"" \
      \; new-win \
      \; split-win -h -d
  fi
  exec tmux attach -t stream
}

cmd=${1:-new}
shift

case "$cmd" in
new)
  $cmd "$@"
  ;;
*)
  echo "Invalid subcommand '$cmd'" >&2
  exit 1
  ;;
esac
