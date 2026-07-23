# Source this file before running `docker compose`
# It's for containers running Alpine, since there's no mDNS resolver

mdns_resolve() {
  local host=$1
  avahi-resolve -4 -n "$host" | awk '{ print $2 }'
}

# set -a
MAK_LOCAL_IP=$(mdns_resolve mak.local)
WUUK_LOCAL_IP=$(mdns_resolve ing-wuuk.local)
WYZE1_LOCAL_IP=$(mdns_resolve ing-wyze-1.local)
PULSE_SERVER=tcp:mak.local:4713
GID=$(id -g)

# Export all vars for docker compose environment.
export MAK_LOCAL_IP WUUK_LOCAL_IP WYZE1_LOCAL_IP PULSE_SERVER GID UID
# set +a
