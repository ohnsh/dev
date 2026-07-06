hw_vtb() {
  # videotoolbox quality parameter: `-q:v` [1-200]
  # 50-65: standard, corresponding to crf 23
  # 75-85: high-quality

  # H.264 VideoToolbox
  ffmpeg -i input.mp4 -c:v h264_videotoolbox -q:v 60 output.mp4

  # HEVC / H.265 VideoToolbox
  ffmpeg -i input.mp4 -c:v hevc_videotoolbox -q:v 65 output.mp4

  # `-hwaccel videotoolbox` required for hw decoding.
  # example: hardware transcode with hardware filter:
  ffmpeg -hwaccel videotoolbox -i input.mp4 \
    -vf "scale_videotoolbox=w=1920:h=1080" \
    -c:v hevc_videotoolbox -q:v 60 output.mp4
}

hw_vaapi() {
  # `-rc_mode CQP` combined with `-global_quality` (or `-qp`) [1-51]
  # 20-23: excellent
  # 24-26: baseline
  # 28-32: lower quality

  # Also: `-rc_mode VBR` (plus `-bv`) and `-rc_mode CBR` (with `-b:v` and `-maxrate`)

  # H.264 VAAPI (Requires initializing the hardware device first)
  ffmpeg -vaapi_device /dev/dri/renderD128 -i input.mp4 \
    -vf 'format=nv12,hwupload' -c:v h264_vaapi -rc_mode CQP -global_quality 24 output.mp4

  # HEVC / H.265 VAAPI
  ffmpeg -vaapi_device /dev/dri/renderD128 -i input.mp4 \
    -vf 'format=nv12,hwupload' -c:v hevc_vaapi -rc_mode CQP -global_quality 25 output.mp4

  # optimized pure-GPU transcode
  # (important not to download frames to CPU and re-upload for encoding)
  # (important to use vaapi-specific (hardware) filters):
  ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi \
    -i input.mp4 \
    -vf "scale_vaapi=w=1920:h=1080" \
    -c:v h264_vaapi -rc_mode CQP -global_quality 24 output.mp4

  # sw decode + hw encode
  # `-init_hw_device vaapi=gpu:...` and `-filter_hw_device gpu` strictly required by
  # newer versions of FFmpeg. Tells `hwupload` which hardware device it is allowed to use
  ffmpeg -init_hw_device vaapi=gpu:/dev/dri/renderD128 -filter_hw_device gpu \
    -i input.mp4 \
    -vf "drawtext=text='Watermark':x=10:y=10:fontsize=24:fontcolor=white,format=nv12,hwupload" \
    -c:v h264_vaapi -rc_mode CQP -global_quality 24 output.mp4

  # hw decode + sw filters + hw encode
  ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi \
    -i input.mp4 \
    -vf "hwdownload,format=nv12,drawtext=text='Watermark':x=10:y=10,format=nv12,hwupload" \
    -c:v h264_vaapi -rc_mode CQP -global_quality 24 output.mp4

  # `-vaapi_device DEV`: legacy shortcut. tells `h264_vaapi` which device to use.
  # implicitly converted to:
  #   -init_hw_device vaapi=vaapi0:DEV -filter_hw_device vaapi0

  # `-hwaccel vaapi -hwaccel_device DEV`: decoder selector
  # Does not automatically communicate with software filtergraphs or encoders
  # down the pipeline unless you combine it with `-hwaccel_output_format vaapi`

  # `-init_hw_device vaapi=NAME@DEV`: modern, flexible way to initialize hw.
  # combine with `-filter_hw_device gpu` and/or `-hwaccel_device gpu`

  # A modern, production command:
  ffmpeg \
    -init_hw_device vaapi=gpu:/dev/dri/renderD128 \
    -filter_hw_device gpu \
    -hwaccel vaapi -hwaccel_device gpu -hwaccel_output_format vaapi \
    -i input.mp4 \
    -vf "hwdownload,format=nv12,drawtext=text='Watermark':x=10:y=10,format=nv12,hwupload" \
    -c:v h264_vaapi output.mp4
}

