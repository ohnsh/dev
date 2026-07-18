mdns_resolve() {
  local host=$1
  avahi-resolve -4 -n "$host" | awk '{ print $2 }'
}

set -a # Export all vars for docker compose environment
BUGDIR=/recordings
MAK_LOCAL_IP=$(mdns_resolve mak.local)
export UID
GID=$(id -g)
set +a
