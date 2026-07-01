#!/usr/bin/env bash

pip_basic() {
  local input=$1
  shift
  ffmpeg -i "$input" -filter_complex "
[0:v]split=2[main_raw][pip_raw];
[main_raw]crop=1920:1080:0:0[main];
[pip_raw]crop=1920:1080:1920:0,scale=480:270[pip];
[main][pip]overlay=W-w-20:20[out]" \
    -map "[out]" -map 0:a:0? -c:v libx264 -c:a copy \
    "$@"
}

pip_mask_shadow() {
  local input=$1
  shift
  ffmpeg -i "$input" -filter_complex "
[0:v]split=2[main_raw][pip_raw];
[main_raw]crop=1920:1080:0:0[main];
[pip_raw]crop=1920:1080:1920:0,scale=480:270,format=rgba[pip];
[pip]split=2[pip_v][pip_m];
[pip_m]alphaextract,geq='if(lte(X,20)*lte(Y,20),if(lte((X-20)^2+(Y-20)^2,400),255,0),if(gte(X,W-20)*lte(Y,20),if(lte((X-W+20)^2+(Y-20)^2,400),255,0),if(lte(X,20)*gte(Y,H-20),if(lte((X-20)^2+(Y-H+20)^2,400),255,0),if(gte(X,W-20)*gte(Y,H-20),if(lte((X-W+20)^2+(Y-H+20)^2,400),255,0),255))))'[mask];
[pip_v][mask]alphamerge[pip_rounded];
color=s=480x270:c=black@0.6,pad=580:370:50:50:0x00000000,boxblur=10:5[shadow];
[shadow][pip_rounded]overlay=50:50[pip_with_shadow];
[main][pip_with_shadow]overlay=W-w-20:20" \
    -c:v libx264 "$@"
}

pip_melt() {
  # out=300 means the clip stops after 300 frames
  # (there must be a better way to limit duration)
  melt -profile atsc_1080p_30 \
    "$1" out=300 \
    -filter crop center=0 left=0 top=0 right=1920 bottom=1080 \
    -track \
    "$1" out=300 \
    -filter crop center=0 left=1920 top=0 right=0 bottom=1080 \
    -filter qtcrop radius=.2 \
    -filter dropshadow radius=.1 \
    -transition affine rect="1340/700:500x281" \
    -consumer avformat:"$2" vcodec=libx264 acodec=aac
}

case "$1" in
pip_basic | pip_mask_shadow | pip_melt)
  CMD=$1
  shift
  $CMD "$@"
  ;;
*)
  echo "Specify a subcommand: pip_basic | pip_mask_shadow | pip_melt" >&2
  exit 1
  ;;
esac
