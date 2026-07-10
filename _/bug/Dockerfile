FROM alpine:latest

RUN apk add --no-cache ffmpeg libpulse bash

WORKDIR /app

COPY bug-alpine.sh /app/bug.sh
RUN chmod +x /app/bug.sh

ENTRYPOINT ["/app/bug.sh"]
