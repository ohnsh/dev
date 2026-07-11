#!/usr/bin/env bash

BUGDIR=${BUGDIR:-/recordings}

# When in a container, no mdns resolver is available but the host
# mapping is added via the command line. In that case, just leave the
# hostname in PULSE_SERVER and let the system resolve it.
maybe_resolve() {
  local host=$1
  if [[ $host == *.local ]] && which avahi-resolve >/dev/null 2>&1; then
    avahi-resolve -4 -n "$host" | cut -f 2
  else
    echo "$host"
  fi
}

bug_ffmpeg_pulse() {
  local seg_length=3600 # one hour

  # IMPORTANT: default source must be configed in pulseaudio.
  #
  # Background: pulseaudio source names on macOS are incredibly unhelpful.
  # For Samson G-Track Pro, `pactl list sources short` gives:
  #
  # Front_Left__Front_Right.2
  #
  # Instead, we'll use the default source, which must be configured on the server.
  exec ffmpeg -hide_banner -y \
    -f pulse -i "default" \
    "${codec[@]}" \
    -f segment -segment_time "$seg_length" \
    -reset_timestamps 1 -segment_atclocktime 1 \
    -strftime 1 -use_wallclock_as_timestamps 1 \
    "$BUGDIR/bug_%Y%m%d_%H%M%S.$ext"
}

bug_aac() {
  local codec=(-c:a aac -b:a 128k)
  local ext=aac
  bug_ffmpeg_pulse
}

bug_opus() {
  local codec=(-c:a libopus -b:a 64k)
  local ext=opus
  bug_ffmpeg_pulse
}

mkdir -p "$BUGDIR"

host=${1:-mak.local}
# override PULSE_SERVER if an explicit host is passed.
if [[ -z $PULSE_SERVER ]] || [[ -n $1 ]]; then
  PULSE_SERVER="tcp:$(maybe_resolve "$host"):4713"
fi

export PULSE_SERVER
echo "Recording audio from server: $PULSE_SERVER" >&2

# Should make format (aac or opus) configurable via environment. For now, just use opus.
bug_opus
