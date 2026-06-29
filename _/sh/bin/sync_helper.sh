SRC=/Volumes/Media
DST=${SYNC_VOL:-/Volumes/Backup}
DST=${DST%/}

FC_BCK="$HOME/Movies/Final Cut Backups.localized"

RCLONE=_rclone.sh

RN="--track-renames"

if [ "$DST" = "/Volumes/Expansion" ]; then
  export HDD=1
fi
# try single-threaded always
export HDD=1

_title() {
  printf "\n$1\n%.${#1}s\n" ----------------------------
}

for category in ${SYNC:-days lib misc proj}; do
  case "$category" in
    days)
      _title DAYS &&
      $RCLONE copy "$@" "$SRC/days" "$DST/days"
      ;;
    lib)
      _title LIB &&
      $RCLONE sync "$@" $RN "$SRC/lib" "$DST/lib"
      ;;
    misc)
      _title MISC &&
      $RCLONE sync $RN \
        --exclude ".*/**" \
        --exclude "node_modules/**" \
        --exclude "dist/**" \
        --exclude "__pycache__/**" \
        "$@" "$HOME/_" "$SRC/_"
      ;;
    proj)
      # _title FC-BCK &&
      # $RCLONE sync "$@" "$FC_BCK" "$SRC/projects/fc-bck" &&
      _title PROJ   &&
      $RCLONE sync "$@" "$SRC/projects" "$DST/projects"
      ;;
  esac
done

echo

# Store arguments safely in an array
# OPTS=( "*.txt" "-v" "--long-option=foo bar" )
# Expand with quoting preserved
# command "${OPTS[@]}"
