#!/bin/sh

_freetsa=$(dirname "$(which $0 || echo $0)")/_freetsa.sh
[ -e "$_freetsa" ] || {
  echo "ERROR: can't find _freetsa.sh" >&2
  exit 1
}
. "$_freetsa"

_stamp() {
  local target=$1
  if [ -e "$target.tsq" -o -e "$target.tsr" ]; then
    echo "Skipping FreeTSA: $target.ts[qr] already exists."
  else
    _freetsa_stamp  "$target"
    _freetsa_verify "$target"
  fi

  if [ -e "$target.ots" ]; then
    echo "Skipping OTS: $target.ots already exists."
  else
    ots stamp "$target"
  fi
}

_manifest_files() {
  find "$1" -type f ! -path "*/*.nostamp/*" \
    ! -name "manifest*.txt" ! -path "*/.*" |\
    sort
}

rm_first_col() {
  # `cut` is the most obvious approach but replaces spaces in filenames with tabs.
  # cut -w -f 2-
  sed -E 's/^[^ ]+[ ]+//'
}

gen_manifest() {
  local _dir=$1 _wdir=${LOGSTAMP_WDIR:-$1/../../..}
  local dir=$(realpath "$_dir") wdir=$(realpath "$_wdir")
  local path=${dir#$wdir/} default_mdir=${dir%/*}/_manifest
  local base_mname=manifest_${path//\//_}

  MDIR=${LOGSTAMP_MDIR:-$default_mdir}
  mkdir -pv "$MDIR"
  MNAME=$base_mname.txt


  if [ -e "$MDIR/$MNAME" ]; then
    local _tmp=$(mktemp -u) seq=1
    mkfifo "$_tmp"
    if [ "$LOGSTAMP_CHECK" != 1 ]; then
      cat "$MDIR/$base_mname"*.txt | rm_first_col | sort > "$_tmp" &
      manifest=$( cd "$wdir" && \
        _manifest_files "$path" | comm -23 - "$_tmp" | xargs -I % sha256sum %
      )
    else
      cat "$MDIR/$base_mname"*.txt | sort > "$_tmp" &
      manifest=$( cd "$wdir" && \
        _manifest_files "$path" | xargs -I % sha256sum % | sort | comm -23 - "$_tmp"
      )
    fi
    [ -n "$_tmp" ] && rm -f "$_tmp"
  else
    manifest=$( cd "$wdir" && \
      _manifest_files "$path" | xargs -I % sha256sum %
    )
  fi

  while [ -e "$MDIR/$MNAME" ]; do
    MNAME=${base_mname}_$seq.txt
    seq=$(expr $seq + 1)
  done

  if [ -n "$manifest" ]; then
    echo "$manifest" | sort -k2 > "$MDIR/$MNAME"
  else
    echo "Nothing new for manifest; none written."
    return 1
  fi

  # local manifest=$(
  #   cd "$wdir" && \
  #   find "$path" -type f ! -path "*/*.nostamp/*" \
  #     ! -name "manifest*.txt" ! -path "*/.*"     \
  #     -print0 | xargs -0 sha256sum | sort
  # )

  # while [ -e "$MDIR/$MNAME" ]; do
  #   sort < "$MDIR/$MNAME" > "$sort_tmp" &
  #   manifest=$(echo "$manifest" | comm -23 - "$sort_tmp")
  #   [ -n "$manifest" ] || break
  #   MNAME=${base_mname}_$seq.txt
  #   seq=$(expr $seq + 1)
  # done

  # [ -n "$sort_tmp" ] && rm -f "$sort_tmp"
}

case "$1" in
  manifest|stamp)
    mode="$1"
    shift
    ;;
  *)
    mode=logstamp
    ;;
esac

while [ $# -gt 1 ]; do
  case "$1" in
    -w) LOGSTAMP_WDIR=$2
        shift 2 ;;
    -m) LOGSTAMP_MDIR=$2
        shift 2 ;;
     *) break   ;;
  esac
done

for target; do
  case "$(basename "$target")" in
    _manifest*)
      echo "Skipping $target"
      continue
      ;;
  esac
  
  case "$mode" in
    manifest)
      gen_manifest "$target"
      ;;
    stamp)
      _stamp "$target"
      ;;
    logstamp)
      gen_manifest "$target" && _stamp "$MDIR/$MNAME"
      ;;
  esac
done
