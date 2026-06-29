OFFSET=-5:00

extract_date() {
  local file=$1 tag=$2

  exiftool \
    -p "\${$tag}"              \
    -d "%Y-%m-%d_%H-%M-%S"     \
    -globalTimeShift "$OFFSET" \
    "$file" 2>/dev/null
}

rename() {
  dto=$(extract_date "$1" "DateTimeOriginal")
  [ -n "$dto" ] || dto=$(extract_date "$1" "CreateDate")

  ext=${1##*.}

  seq=0
  dest=memo-$dto.$ext

  while [ -e "$dest" ]; do
    seq=$((seq + 1))
    dest=memo-${dto}_$seq.$ext
  done

  if [ -n "$DRY_RUN" ]; then
    echo "mv -nv \"$1\" \"$dest"
  else
    mv -nv "$1" "$dest" && \
      for aux in "${1%.*}".*; do
        [ -e "$aux" ] || break
        mv -nv "$aux" "${dest%.*}.${aux##*.}"
      done
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    -o) OFFSET=$2
        shift 2
        ;;
    -d) DRY_RUN=1
        shift
        ;;
     *) break
        ;;
  esac
done

for memo; do
  rename "$memo"
done
