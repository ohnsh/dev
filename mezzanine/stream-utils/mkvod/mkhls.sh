#!/usr/bin/env bash

script_dir=$(dirname "$(which "$0" || echo "$0")")
. "$script_dir/lib.sh"

hls_copy() {
    mkdir -p "$outdir/copy"
    $ffmpeg -i "$1" \
        -codec: copy \
        -hls_time 6 \
        -hls_playlist_type vod \
        -hls_segment_filename "$outdir/copy/segment_%03d.ts" \
        -f hls "$outdir/copy/playlist.m3u8"
}

hls_xcode() {
    mkdir -p "$outdir/720p"
    $ffmpeg -i "$1" \
        -vf "scale=$_720p" \
        -c:v libx264 -b:v 4M -maxrate:v 6M -bufsize:v 8M \
        -c:a aac -b:a 128k -ac 2 \
        -hls_time 6 \
        -hls_playlist_type vod \
        -hls_segment_filename "$outdir/720p/seg_%03d.ts" \
        -f hls "$outdir/720p/playlist.m3u8"
}

hls_xcode_hw() {
    local _outdir="$outdir/720p-hw"
    mkdir -p "$_outdir"
    $ffmpeg -hwaccel videotoolbox -i "$1" \
        -vf "scale=$_720p" \
        -c:v h264_videotoolbox -b:v 4M -maxrate:v 6M -bufsize:v 8M \
        -profile:v high \
        -c:a aac -b:a 128k -ac 2 \
        -hls_time 6 \
        -hls_playlist_type vod \
        -hls_segment_filename "$_outdir/seg_%03d.ts" \
        -f hls "$_outdir/playlist.m3u8"
}

hls_xcode_hw_hevc() {
    local _outdir="$outdir/720p-hevc"
    mkdir -p "$_outdir"
    $ffmpeg -hwaccel videotoolbox -i "$1" \
        -vf "scale=$_720p" \
        -c:v hevc_videotoolbox -b:v 4M -maxrate:v 6M -bufsize:v 8M \
        -tag:v hvc1 \
        -c:a aac -b:a 128k -ac 2 \
        -hls_time 6 \
        -hls_playlist_type vod \
        -hls_segment_type fmp4 \
        -hls_segment_filename "$_outdir/seg_%03d.m4s" \
        -f hls "$_outdir/playlist.m3u8"
}

# https://www.mux.com/articles/how-to-convert-mp4-to-hls-format-with-ffmpeg-a-step-by-step-guide
hls_multi() {
    $ffmpeg -i "$1" \
        -filter_complex \
        "[0:v]split=3[v1][v2][v3]; \
         [v1]scale=${_1080p}[v1out]; \
         [v2]scale=${_720p}[v2out]; \
         [v3]scale=${_480p}[v3out]" \
        -map "[v1out]" -c:v:0 libx264 -b:v:0 5000k -maxrate:v:0 5350k -bufsize:v:0 7500k \
        -map "[v2out]" -c:v:1 libx264 -b:v:1 2800k -maxrate:v:1 2996k -bufsize:v:1 4200k \
        -map "[v3out]" -c:v:2 libx264 -b:v:2 1400k -maxrate:v:2 1498k -bufsize:v:2 2100k \
        -c:a aac -ac 2 \
        -map a:0 -b:a:0 192k \
        -map a:0 -b:a:1 128k \
        -map a:0 -b:a:2 96k \
        -f hls \
        -hls_time 10 \
        -hls_playlist_type vod \
        -hls_flags independent_segments \
        -hls_segment_type mpegts \
        -hls_segment_filename "$outdir/stream_%v/seg_%03d.ts" \
        -master_pl_name "master.m3u8" \
        -var_stream_map "v:0,a:0 v:1,a:1 v:2,a:2" \
        "$outdir/stream_%v/playlist.m3u8"
}

pre_process() {
    if [ -n "$PORTRAIT" ]; then
        _1080p=1080:-2
        _720p=720:-2
        _480p=480:-2
    else
        _1080p=-2:1080
        _720p=-2:720
        _480p=-2:480
    fi
}

case "$1" in
hls_copy | hls_xcode | hls_xcode_hw | hls_xcode_hw_hevc | hls_multi)
    CMD=$1
    shift

    for file; do
        if ! [ -f "$file" ]; then
            echo "error: skipping non-file $file" >&2
            continue
        elif ! probe_vid "$file"; then
            echo "error: skipping non-video file $file" >&2
            continue
        fi

        echo "processing video $file $(get_stats)" >&2

        outdir=$(get_outdir "$file")/hls
        mkdir -p "$outdir"

        pre_process &&
            $CMD "$file"
    done
    ;;
*)
    echo "valid subcommands: hls_copy, hls_xcode, hls_xcode_hw, hls_xcode_hw_hevc, hls_multi" >&2
    exit 1
    ;;
esac

# https://yehiaabdelm.com/blog/roll-your-own-hls
# -hls_flags independent_segments
# -force_key_frames expr:gte(t,n_forced*6)
# -hls_time: target segment duration
# -hls_playlist_type vod: static playlist (unlike live streams)
# -hls_base_url baseurl (prepend to playlist items)
