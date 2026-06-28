#!/usr/bin/env bash

script_dir=$(dirname "$(which "$0" || echo "$0")")
. "$script_dir/lib.sh"

VF_HDR="zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"

# shellcheck disable=SC2086
# Using arrays would make it too clunky to provide default fallback options.
# Old-fashioned unquoted OPTION variables are the lesser of many evil alternatives.
# (only because ffmpeg options are fairly predictably safe to leave unquoted)
# (don't quote me on that)
webp_seq() {
    # Q="-qv: 75"
    local vf=$VF
    [ -n "$HDR" ] && vf="${vf:+$vf,}$VF_HDR"
    vf="${vf:+$vf,}$IMG_SCALE"

    $ffmpeg $IN_OPTS -i "$1" \
        -vf "$vf" \
        -c:v libwebp \
        -fps_mode vfr \
        $LIMIT $Q $OUT_OPTS "$2"
}

# shellcheck disable=SC2086
jpeg_seq() {
    # Q="-qv: 2"
    local vf=$VF
    [ -n "$HDR" ] && vf="${vf:+$vf,}$VF_HDR"
    vf="${vf:+$vf,}$IMG_SCALE"

    $ffmpeg $IN_OPTS -i "$1" \
        -vf "$vf" \
        -fps_mode vfr \
        $LIMIT $Q $OUT_OPTS "$2"
}

# shellcheck disable=SC2086
thumb() {
    # thumbnail filter:
    #  - buffers 100 frames into memory
    #  - analyzes the color palettes and contrasts
    #  - picks the single "most representative" frame
    #  - discards the other 99 frames.
    # Q="-qv: 75"
    local vf=$VF
    [ -n "$HDR" ] && vf="${vf:+$vf,}$VF_HDR"
    vf="${vf:+$vf,}thumbnail,$IMG_SCALE"

    $ffmpeg $IN_OPTS -i "$1" \
        -vf "$vf" \
        -frames:v 1 \
        $Q $OUT_OPTS "$2"
}

# shellcheck disable=SC2086
webm() {
    # Q="-crf 30"
    $ffmpeg $IN_OPTS -i "$1" \
        -vf "${VF:-"fps=15,$SCALE"}" \
        -c:v libvpx-vp9 -row-mt 1 \
        -map 0:v \
        $LIMIT $Q $OUT_OPTS "$2"
}

# shellcheck disable=SC2086
webp_anim() {
    local vf=${VF:-"fps=15"}
    [ -n "$HDR" ] && vf="${vf:+$vf,}$VF_HDR"
    vf="${vf:+$vf,}$SCALE"

    $ffmpeg $IN_OPTS -i "$1" \
        -vf "$vf" \
        -c:v libwebp_anim -loop 0 \
        $LIMIT $Q $OUT_OPTS "$2"
}

iframes="select='eq(pict_type,I)'"
everynth() {
    echo "select='not(mod(n,$1))'"
}
fastfwd="setpts=N/FRAME_RATE/TB"

IN_OPTS=
OUT_OPTS="-y"
VF=
LIMIT="-frames:v 5"
Q=
# IN_OPTS="-ss 60"
# LIMIT="-t 5"

for file; do
    if ! [ -f "$file" ]; then
        echo "error: skipping non-existent file $file" >&2
        continue
    elif ! probe_vid "$file"; then
        echo "error: skipping non-video file $file" >&2
        continue
    fi

    echo "processing video $file $(get_stats)" >&2
    outdir=$(get_outdir "$file")

    SCALE=scale=640:-2
    IMG_SCALE=scale=1280:-2
    if [ -n "$PORTRAIT" ]; then
        SCALE=scale=-2:640
        IMG_SCALE=scale=-2:1280
    fi

    mkdir -p "$outdir"

    # VF="$iframes,$(everynth 20),$IMG_SCALE"
    # webp_seq "$file" "$outdir/seq/thumb%d.webp"

    VF=
    webp_anim "$file" "$outdir/preview.webp"
    webm "$file" "$outdir/preview.webm"
    thumb "$file" "$outdir/thumb.webp"
done

# does input-seeking use http content range for efficiency?
# 	-i https://storage.example.com/videos/sample.mp4

# scene detection
# 	-vf "select=gt(scene\,0.4),$IMG_SCALE"
