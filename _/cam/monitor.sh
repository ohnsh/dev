#!/usr/bin/env bash

usage() { cat; } <<EOF
Usage:
  $(basename "$0") <> "\$STATUS_FIFO"

Description:
  Opening the status FIFO for read/write is crucial so that EOF isn't sent on
  every status update. This is because the FIFO always has at least one writer:
  $(basename "$0") itself.

EOF

if [[ $# -ne 0 ]]; then
  usage
  exit 1
fi

while read -r script status; do
  echo "$script: $status" >&2
  curl -d "$script: $status" \
    https://ntfy.sh/ohnsh-push
done
