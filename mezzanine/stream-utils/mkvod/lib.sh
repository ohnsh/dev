ffmpeg="ffmpeg -hide_banner -v warning"

find_vids() {
    local dir=$1
    shift

    find "$dir" \
        -type f \
        ! -path "*/.*" \
        ! -path "*/_/*" \
        \( -iname "*.mp4" -or -iname "*.mov" \) \
        "$@"
}

_probe_vid() {
    local file=$1
    local width height nb_frames duration rotation
    local color_space color_transfer color_primaries
    local ENTRIES=stream=width,height,nb_frames,duration,color_space,color_transfer,color_primaries
    ENTRIES="$ENTRIES:stream_side_data=rotation"
    (
        eval "$(
            ffprobe -v error \
                -select_streams v:0 \
                -show_entries "$ENTRIES" \
                -of default=noprint_wrappers=1 \
                "$file"
        )"
        echo "WIDTH=$width"
        echo "HEIGHT=$height"
        echo "NB_FRAMES=$nb_frames"
        echo "DURATION=$duration"
        echo "ROTATION=$rotation"
        echo "COLOR_SPACE=$color_space"
        echo "COLOR_TRANSFER=$color_transfer"
        echo "COLOR_PRIMARIES=$color_primaries"
    )
}

probe_vid() {
    local file=$1
    eval "$(_probe_vid "$file")"

    # shellcheck disable=SC2153
    if [ -z "$NB_FRAMES" ] || [ "$NB_FRAMES" = "1" ] || [ "$DURATION" = "N/A" ]; then
        return 1
    fi

    PORTRAIT=
    # shellcheck disable=SC2153
    if [ "${ROTATION:-0}" -ne 0 ] || [ "$WIDTH" -lt "$HEIGHT" ]; then
        PORTRAIT=1
    fi

    # color_space=bt2020nc
    HDR=
    case "${COLOR_TRANSFER:-bt709}" in
    arib-std-b67 | smpte2084)
        HDR=1
        ;;
    bt709 | unknown) ;;
    esac
}

get_stats() {
    local stats
    stats=$(
        IFS=,
        set -- ${PORTRAIT:+portrait} ${HDR:+hdr}
        echo "$*"
    )
    echo ${stats:+"($stats)"}
}

get_outdir() {
    local input prefix stem
    input=$(realpath "$1")
    prefix=${input%%/days/*}
    stem=${input#"$prefix/days/"}
    echo "$prefix/overlay/$stem"
}
