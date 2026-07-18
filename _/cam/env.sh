mdns_resolve() {
  local host=$1
  avahi-resolve -4 -n "$host" | awk '{ print $2 }'
}

MAK_LOCAL_IP=$(mdns_resolve mak.local)
WUUK_LOCAL_IP=$(mdns_resolve ing-wuuk.local)
WYZE1_LOCAL_IP=$(mdns_resolve ing-wyze-1.local)
PULSE_SERVER=tcp:mak.local:4713
export UID
GID=$(id -g)
