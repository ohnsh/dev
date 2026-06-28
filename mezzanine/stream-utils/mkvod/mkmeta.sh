#!/usr/bin/env bash

script_dir=$(dirname "$(which "$0" || echo "$0")")
. "$script_dir/lib.sh"

append_json() {
    jq \
        --arg duration "$DURATION" \
        --arg rotation "$ROTATION" \
        --arg color_space "$COLOR_SPACE" \
        --arg color_transfer "$COLOR_TRANSFER" \
        --arg color_primaries "$COLOR_PRIMARIES" \
        '.[] + { FFprobe: { Duration: $duration, Rotation: $rotation, ColorSpace: $color_space, ColorTransfer: $color_transfer, ColorPrimaries: $color_primaries } }'
}

for file; do
    if ! [ -f "$file" ]; then
        echo "error: skipping non-file $file" >&2
        continue
    elif ! probe_vid "$file"; then
        echo "error: skipping non-video file $file" >&2
        continue
    fi

    echo "processing video $file $(get_stats)" >&2

    outdir=$(get_outdir "$file")
    mkdir -p "$outdir"

    exiftool -api QuickTimeUTC -j -g2 "$file" | append_json > "$outdir/meta.json"
done
