#!/usr/bin/env bash

# Client-side script used with launchd for automation.
# stdout and stderr are redirected to files in $HOME/_/logs

CRON_DIR=${CRON_DIR:-$HOME/_/cron}
mkdir -p "$CRON_DIR"

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
  local remote_dir=Export/bug-archive
  local local_dir=$CRON_DIR/bug-archive

  ssh bug-archive &&
    scp -r "$remote_dir" "$local_dir" &&
    ssh bug-archive-clean

  # dxif.sh -1 bug-archive
  # cd "$mo"
  # logstamp.sh */*
}

# launchd runs jobs in a nearly-empty environment
if [[ -z $PROFILE ]]; then
  export PROFILE=$HOME/.bash_profile
  . "$PROFILE"
fi

# scp -i "$HOME/.ssh/id_ed25519_scp" -r jms@box.local:Export/bug bug # ...

# rclone paths are based in $HOME/Export on remote host.
# rclone copy -P box:bug bug

# logstamp.sh /Volumes/Media/

cmd=${1//-/_}
shift

case "$cmd" in
ssh | env | scp | bug_archive)
  $cmd "$@"
  ;;
*)
  echo "Invalid subcommand '$cmd'" >&2
  exit 1
  ;;
esac
