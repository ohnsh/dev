mdns_resolve() {
  local host=$1
  if command -v avahi-resolve &>/dev/null; then
    avahi-resolve -4 -n "$host" | awk '{ print $2 }'
  else
    # `hosts` db uses legacy API and returns only one entry.
    # `ahosts` and `ahostsv{4,6}` use the modern API and generally return several entries.
    # despite being an NSS/glibc utility, works on musl/alpine but without mDNS support.
    getent hosts "$host" | awk '{ print $1 }'
  fi
}

# walk from the project root (marked by .git or package.json) to the script directory,
# sourcing all {.env,.env.*} files along the way. Sourcing happens with the `allexport`
# shell option set so that the environment is modified.
load_dotenv() {
  local script_dir=$(dirname "${BASH_SOURCE[0]}")
  local dir=$script_dir
  local dotenv i
  local stack=()

  while [[ -n $dir ]]; do
    for dotenv in "$dir"/.env{,.*}; do
      # always expands to at least .env, even if it doesn't exist
      [[ -f "$dotenv" ]] || continue
      stack+=("$dotenv")
    done
    # Don't walk past project root (marked by package.json OR .git)
    [[ -f "$dir/package.json" || -d "$dir/.git" ]] && break
    # Move to parent directory for next iteration
    dir=${dir%/*}
  done

  # Source dotenv files with allexport set so that environment is modified
  # without the files needing an explicit `export` on every line.
  set -o allexport

  # Start at the top of the stack by looping backwards. This ensures that
  # nearer/more specific dotenv files override those closer to the project root.
  for ((i = 1; i <= ${#stack[@]}; i++)); do
    dotenv=${stack[-i]}
    . "$dotenv"
  done
  set +o allexport
}

fstatus() {
  # Log to stderr and FIFO if available.
  # Detect if the FIFO has a reader, to prevent blocking.
  if [[ -w $STATUS_FIFO ]] && fuser "$STATUS_FIFO" &>/dev/null; then
    printf "%s\t%s\n" "${script_name:-$0}" "$*" | tee "$STATUS_FIFO" >&2
  else
    printf "%s*\t%s\n" "${script_name:-$0}" "$*" >&2
  fi
}

default_hosts=(ing-wuuk.local ing-wyze-1.local mak.local)
get_host_mappings() {
  local ip
  [[ -n $* ]] || set -- "${default_hosts[@]}"
  for host; do
    if [[ $host == *.local ]]; then
      ip=$(mdns_resolve "$host") || {
        echo "Error resolving mdns name $host. (Is avahi-resolve installed?)" >&2
        exit 1
      }
      host_mappings+=(--add-host "$host:$ip")
    fi

  done
}
