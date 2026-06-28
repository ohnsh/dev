#!/usr/bin/env bash

ffmpeg -i "$1" -filter_complex "
[0:v]setpts=PTS/8,split=4[tl_raw][tr_raw][bl_raw][br_raw];

[tl_raw]crop=1920:1080:0:0[tl];
[tr_raw]crop=1920:1080:1920:0[tr];
[bl_raw]crop=1920:1080:0:1080,fps=fps=2[bl];
[br_raw]crop=1920:1080:1920:1080,fps=fps=2[br];

[tl][tr][bl][br]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0[v];
[0:a]atempo=8.0[a]
" -map "[v]" -map "[a]" \
  -c:v libx265 -preset fast -tag:v hvc1 -shortest "$2"

# default crf: 23 (libx264), 28 (libx265)
# `-preset` trades off speed and file size, quality remains constant
# slow, medium, fast, veryfast
# optional audio stream (no error if absent):
# `-map 0:a?`
