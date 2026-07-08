#!/usr/bin/env bash

bug=${BASH_SOURCE[0]%/*}/bug.sh

/opt/homebrew/bin/tmux new-session -d -A -s bug "$bug"
