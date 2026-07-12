FROM bluenviron/mediamtx:latest-rpi AS mediamtx
FROM alpine:latest

# bluenviron/mediamtx images with non-`rpi` tag seem to be amd64 images, although they
# run on the pi as far as I can tell.

COPY --from=mediamtx /mediamtx /
COPY --from=mediamtx /mediamtx.yml /

# add anything you need.
RUN apk add --no-cache ffmpeg

ENTRYPOINT [ "/mediamtx" ]
