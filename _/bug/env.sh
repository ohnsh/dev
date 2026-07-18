mdns_resolve() {
  local host=$1
  avahi-resolve -4 -n "$host" | awk '{ print $2 }'
}

BUGDIR=/recordings
MAK_LOCAL_IP=$(mdns_resolve mak.local)
export UID
GID=$(id -g)
