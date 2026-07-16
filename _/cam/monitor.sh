#!/usr/bin/env bash

while read -r script status; do
  echo "$script: $status" >&2
  curl -d "$script: $status" \
    https://ntfy.sh/ohnsh-push
done
