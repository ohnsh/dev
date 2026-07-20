#!/usr/bin/env bash

# Client-side script used with launchd for automation.
# stdout and stderr are redirected to files in $HOME/_/logs

# launchd runs jobs in a nearly-empty environment
if [[ -z $PROFILE ]]; then
  export PROFILE=$HOME/.bash_profile
  . "$PROFILE"
fi

# scp -i "$HOME/.ssh/id_ed25519_scp" -r jms@box.local:Export/bug bug # ...

# rclone paths are based in $HOME/Export on remote host.
# rclone copy -P box:bug bug

# logstamp.sh /Volumes/Media/
env
