# from gemini
ffmpeg -re -i input.mp4 -f fifo -fifo_format flv \
  -attempt_recovery 1 -max_recovery_attempts 20 \
  -recovery_wait_time 5 -map 0:v -map 0:a \
  -c copy rtmp://://example.com

# https://ffmpeg.org/ffmpeg-all.html#fifo-1
ffmpeg -re -i ... -c:v libx264 -c:a aac -f fifo -fifo_format flv \
  -drop_pkts_on_overflow 1 -attempt_recovery 1 -recovery_wait_time 1 \
  -map 0:v -map 0:a rtmp://example.com/live/stream_name

# https://www.reddit.com/r/ffmpeg/comments/xvgax1/reconnect_rtmp_stream_after_disconnect_and/
ffmpeg -stream_loop -1 -re -i input.mp4 \
  -f fifo -fifo_format flv -map 0:v -map 0:a \
  -attempt_recovery 1 -max_recovery_attempts 20 \
  -recover_any_error 1 -tag:v 7 -tag:a 10 -recovery_wait_time 5 \
  -flags +global_header -c copy rtmp://example.com/myTarget
