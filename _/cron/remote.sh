#!/usr/bin/env bash

# Forced command for restricted (non-password-protected) SSH key used in cron/launchd
# automation.

echo "$SSH_ORIGINAL_COMMAND"
env
