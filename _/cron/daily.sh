#!/usr/bin/env bash

# Client-side script used with launchd for automation.

# Use ~/Downloads instead?
CRON_DIR=${CRON_DIR:-$HOME/_/cron}
CRON_LOG_DIR=${CRON_LOG_DIR:-$CRON_DIR/logs}

mkdir -p "$CRON_DIR" "$CRON_LOG_DIR"

# We're running inside Ghostty.app to work around macOS permission issues.
# Consequently, the redirections specified in the plist file don't work.
exec >>"$CRON_LOG_DIR/daily.log" 2>>"$CRON_LOG_DIR/daily.err"

ssh() {
  # IdentitiesOnly: don't use ssh-agent
  # BatchMode: don't prompt for password
  # -F /dev/null: don't use config file
  # -T: never request pty
  command ssh \
    -F /dev/null \
    -T \
    -i "$HOME/.ssh/id_ed25519_res" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    jms@box.local \
    remote.sh "$@"
}

scp() {
  local recurse
  if [[ $1 == '-r' ]]; then
    recurse=1
    shift
  fi
  local remote=$1
  local loc=$2
  command scp \
    -F /dev/null \
    -i "$HOME/.ssh/id_ed25519_scp" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    ${recurse:+-r} \
    "jms@box.local:$remote" "$loc"
}

env() {
  command env
}

bug_archive() {
  # technically, this is set on the server by the environment.
  local remote_dir=Export/bug-archive

  # if we name `bug-archive` and it exists, the remote directory will be nested inside it
  # another option might be to append `/*` to remote_dir
  local local_dir=$CRON_DIR

  ssh bug-archive &&
    scp -r "$remote_dir" "$local_dir" &&
    ssh bug-archive-clean

  # dxif.sh -1 bug-archive
  # cd "$mo"
  # logstamp.sh */*
}

cam_archive() {
  # technically, this is set on the server by the environment.
  local remote_dir=Export/cam-archive
  local local_dir=$CRON_DIR/cam-archive

  # Now uses same SSH key and SFTP backend as scp.
  rclone move -P "box:$remote_dir" "$local_dir"
}

script_name=$(basename "$0")
status() {
  echo "$script_name: $*"
}

archive() {
  status "Running archive."

  if bug_archive; then
    status "bug-archive: succeeded."
  else
    status "bug-archive: $? exit status from ssh/scp pipeline."
  fi

  if cam_archive; then
    status "cam-archive: succeeded."
  else
    status "cam-archive: $? exit status from rclone."
  fi

  status "Exiting archive."
}

# launchd runs jobs in a nearly-empty environment
if [[ -z $PROFILE ]]; then
  export PROFILE=$HOME/.bash_profile
  . "$PROFILE"
fi

cmd=${1:-archive}
cmd=${cmd//-/_}
shift

case "$cmd" in
ssh | env | scp | archive | bug_archive | cam_archive)
  echo
  status "[$(date +'%F %T')]"
  status "Running $cmd"
  $cmd "$@"
  ;;
*)
  status "Invalid subcommand '$cmd'"
  exit 1
  ;;
esac
