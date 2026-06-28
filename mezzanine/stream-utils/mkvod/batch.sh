#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$(which "$0" || echo "$0")")

process_dir() {
    local dir=$1
    local cmd=$2
    shift 2

    find "$dir" \
        -type f \
        \( -iname "*.mp4" -or -iname "*.mov" \) \
        -print0 |
        xargs -0 "$SCRIPT_DIR/$cmd.sh" "$@"
}

route_file() {
    $SCRIPT_DIR/mkthumbs.sh "$1" &&
    $SCRIPT_DIR/mkhls.sh hls_xcode_hw_hevc "$1"
}

for file; do
    if [ -f "$file" ]; then
        route_file "$file"
    elif [ -d "$file" ]; then
        process_dir "$file" mkthumbs
        process_dir "$file" mkhls hls_xcode
    else
        echo "skipping $file, not a file or directory" >&2
        continue
    fi
done
