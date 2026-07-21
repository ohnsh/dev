#!/usr/bin/env bash

# Forced command for restricted (non-password-protected) SSH key used in cron/launchd
# automation.

script=$(basename "$0")
# shopt -s extglob
# ssh_cmd=${SSH_ORIGINAL_COMMAND##"$script"?([ ])}
# shopt -u extglob

BUG_DIR=$HOME/Export/bug
ARCHIVE_DIR=$BUG_DIR-archive

bug_archive() {
  mkdir -p "$ARCHIVE_DIR"

  for file in "$BUG_DIR"/*; do
    if [[ -n "$(fuser "$file")" ]]; then
      echo "$file currently open; skipping" >&2
      continue
    fi
    mv -nv "$file" "$ARCHIVE_DIR"
  done
}

bug_archive_clean() {
  rm -rf "$ARCHIVE_DIR"
}

env() {
  command env
}

# possibly eval "set -- $SSH_ORIGINAL_COMMAND" to allow embedded quoting
[[ -n $SSH_ORIGINAL_COMMAND ]] &&
  set -- $SSH_ORIGINAL_COMMAND
[[ $1 == "$script" ]] &&
  shift

cmd=${1//-/_}
shift

case "$cmd" in
bug_archive | bug_archive_clean | env)
  $cmd "$@"
  ;;
*)
  echo "Invalid subcommand '$cmd'" >&2
  exit 1
  ;;
esac
