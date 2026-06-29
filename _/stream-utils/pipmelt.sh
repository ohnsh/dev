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
