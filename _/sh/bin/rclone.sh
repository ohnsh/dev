#!/usr/bin/env bash

OPTS="--progress -l --exclude .DS_Store"
HDD_OPTS="--transfers=1 --multi-thread-streams=0 --local-no-sparse --size-only"

# --no-traverse     # Potential HDD opt
#
# --ignore-existing # Never overwrite anything, ever
# --backup-dir      # Allow updates but save old versions
# --dry-run         # validate before running

if [ -n "$HDD" ]; then
  echo "Using HDD options..." >&2
  OPTS="$OPTS $HDD_OPTS"
fi

if [ -n "$ISROOT" ]; then
  echo "Using root --exclude options..." >&2
  OPTS="$OPTS --exclude /.** --exclude ._*"
fi

case "$1" in
  sync|copy)
    CMD=$1
    shift ;;
  --opts)
    echo "$OPTS"
    exit ;;
  *)
    echo "Error: please specify sync or copy" >&2
    exit 1 ;;
esac

# IMPORTANT: disable pathname expansion,
# especially due to --exclude options above
set -f
rclone $CMD $OPTS "$@"
set +f
