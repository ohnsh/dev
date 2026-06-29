https://www.mux.com/articles/extract-thumbnails-from-a-video-with-ffmpeg

```bash

# filter method, 9 seconds
ffmpeg -i "$VID" \
  -vf "select='gte(t,9)',scale=320:-1" \
  -frames:v 1 thumbnail.png

# one per second
ffmpeg -i "$VID" \
  -vf "fps=1,scale=320:-1" \
  -vsync vfr \
  -q:v 2 thumb%04d.png

# one per I-frame
ffmpeg -i "$VID" \
  -vf "select='eq(pict_type,I)',scale=320:-1" \
  -vsync vfr \
  -q:v 2 thumb%04d.png

# one per 10 I-frames
ffmpeg -i "$VID" \
-vf "select='eq(pict_type,I)',select='not(mod(n,10))',scale=320:-1" \
-vsync vfr \
-q:v 2 thumb%04d.png
```

Gemini:

```bash

# WebM
ffmpeg -ss 00:00:05 -t 3 -i input.mp4 -vf "fps=10,scale=480:-1:flags=lanczos" -c:v libvpx-vp9 -crf 30 -b:v 0 -an output.webm

# Animated GIF
ffmpeg -ss 00:00:05 -t 3 -i input.mp4 -vf "fps=10,scale=480:-1:flags=lanczos:split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 output.gif

```

https://gist.github.com/Spikeysanju/41c88b5a003f2c72340de2900f337f0d

``` bash

ffmpeg -i input.mp4 -vf "thumbnail" -frames:v 1 thumb.png

# extract every 10th frame
ffmpeg -i input.mp4 -vf "select='not(mod(n\,10))',setpts=N/FRAME_RATE/TB" output.mp4

# extract frame
ffmpeg -i input.mp4 -vf "scale=1280:-1" -c:v mjpeg -q:v 3 output.jpg

```

https://medium.com/@sergiu.savva/ffmpeg-mastery-extracting-perfect-thumbnails-from-videos-339a4229bb32

```bash

ffmpeg \
  -hwaccel auto \
  -ss 55.2 \
  -i input_video.mp4 \
  -frames:v 1 \
  -pix_fmt yuv420p \
  -vf scale=640:360:flags=bicubic \
  -f image2 \
  -q:v 2 \
  -y output_thumbnail.jpg

# does input-seeking use http content range for efficiency?
ffmpeg \
  -ss 55.2 \
  -i https://storage.example.com/videos/sample.mp4 \
  -frames:v 1 \
  thumbnail.jpg

ffmpeg \
  -i input_video.mp4 \
  -ss 10 -frames:v 1 thumb-10s.jpg \
  -ss 30 -frames:v 1 thumb-30s.jpg \
  -ss 60 -frames:v 1 thumb-60s.jpg

# scene detection
ffmpeg \
  -i input_video.mp4 \
  -vf "select=gt(scene\,0.4),scale=640:360" \
  -frames:v 5 \
  -vsync vfr \
  thumb-%03d.jp
```

# HLS

https://yehiaabdelm.com/blog/roll-your-own-hls

```python

    quality_name = quality["name"]
    output_dir = Path(tmp_path) / "hls" / quality_name
    output_dir.mkdir(parents=True, exist_ok=True)

    playlist_path = output_dir / "playlist.m3u8"
    segment_pattern = str(output_dir / "segment_%d.ts")

    src_w = int(metadata["width"])
    src_h = int(metadata["height"])

    target_h = min(int(quality["height"]), src_h)
    planned_h = _even(target_h)
    planned_w = _even(int((src_w * planned_h) / src_h))

    vf_chain = f"scale={planned_w}:{planned_h}:force_divisible_by=2,setsar=1"

    cmd = [
        constants.FFmpeg_PATH,
        "-i", video_path,
        "-vf", vf_chain,
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-preset", "fast",
        "-profile:v", "main",
        "-level", "4.0",
        "-b:v", quality["bitrate"],
        "-maxrate", quality["bitrate"],
        "-bufsize", f"{int(str(quality['bitrate']).rstrip('kK')) * 2}k",
        "-c:a", "aac",
        "-b:a", quality["audio_bitrate"],
        "-ac", "2",
        "-ar", "48000",
        "-hls_time", "6",
        "-hls_playlist_type", "vod",
        "-hls_list_size", "0",
        "-hls_flags", "independent_segments",
        "-force_key_frames", "expr:gte(t,n_forced*6)",
        "-hls_segment_filename", segment_pattern,
        "-f", "hls",
        "-y",
        str(playlist_path),
    ]

    # later...
    s3_key = f"videos/{video_id}/hls/{quality_name}/{file_path.name}"

    # Determine content type
    if file_path.suffix == ".m3u8":
        content_type = "application/vnd.apple.mpegurl"
    elif file_path.suffix == ".ts":
        content_type = "video/mp2t"
    else:
        content_type = "application/octet-stream"

```
