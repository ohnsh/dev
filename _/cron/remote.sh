#!/usr/bin/env bash

# Forced command for restricted (non-password-protected) SSH key used in cron/launchd
# automation. In authorized_keys:
#   restrict,command="$HOME/dev/_/cron/remote.sh" ssh-ed25519 KEY1
#
# Separate key supporting automation with rclone and scp:
#   restrict,command="/usr/lib/ssh/sftp-server" ssh-ed25519 KEY2
#
# Previously, I had a separate key and backend for rclone...
#   restrict,command="/usr/bin/rclone serve sftp --stdio $HOME/Export" ssh-ed25519 KEY3
#
# But it's better to simply use the rclone CLI with the existing scp key and OpenSSH sftp
# server. The rclone backend is actually a downgrade because, when run in ssh-activated
# `--stdio` mode, you have to set `--transfers 1` (see `rclone serve sftp --help`). (Note
# that rclone can also run as an independent sftp server, on its own port, without that
# restriction.)

script=$(basename "$0")
# shopt -s extglob
# ssh_cmd=${SSH_ORIGINAL_COMMAND##"$script"?([ ])}
# shopt -u extglob

BUG_DIR=$HOME/Export/bug
ARCHIVE_DIR=$BUG_DIR-archive

lsof_t() {
  local file=$1

  # on a busybox system, we actually want fuser
  # in both cases, the exit status is zero when the file is open, non-zero otherwise.
  if [[ $(readlink "$(command -v lsof)") == */busybox ]]; then
    fuser "$file" 2>/dev/null
  else
    command lsof -t "$file" 2>/dev/null
  fi
}

bug_archive() {
  mkdir -p "$ARCHIVE_DIR"

  for file in "$BUG_DIR"/*; do
    if lsof_t "$file" &>/dev/null; then
      echo "$file currently open; skipping" >&2
      continue
    fi
    mv -nv "$file" "$ARCHIVE_DIR"
  done
}

bug_archive_clean() {
  rm -rf "$ARCHIVE_DIR"
}

# possibly eval "set -- $SSH_ORIGINAL_COMMAND" to allow embedded quoting
set -- $SSH_ORIGINAL_COMMAND
[[ $1 == "$script" ]] && shift

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
