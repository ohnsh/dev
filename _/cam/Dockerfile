FROM bluenviron/mediamtx:latest AS mediamtx
FROM alpine:latest

# note that a `latest-rpi` tag is available for mediamtx which includes libcamera and all
# dependencies required to delcare a pi camera source for mediamtx.
#
# also note that a `latest-ffmpeg` tag is available that is essentially the same as this
# build. I'm keeping this Dockerfile simply to get some more experience building images.

COPY --from=mediamtx /mediamtx /
COPY --from=mediamtx /mediamtx.yml /

# add anything you need.
RUN apk add --no-cache ffmpeg curl tzdata

ENTRYPOINT [ "/mediamtx" ]
