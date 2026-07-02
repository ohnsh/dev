When using the FFmpeg setpts (Set Presentation Timestamp) filter, your expression is evaluated via the FFmpeg [Evaluation API](https://trac.ffmpeg.org/wiki/How%20to%20speed%20up%20/%20slow%20down%20a%20video). You can manipulate time and frame sequencing using the following available variables and constants: [1, 2, 3, 4, 5]

* PTS: The presentation timestamp of the current input frame.
* N: The count of the current frame (starting from 0).
* STARTPTS: The PTS of the very first frame in the video stream.
* T: The time of the current frame (in seconds).
* STARTT: The time in seconds of the first frame (typically 0).
* INTERLACED: Returns 1 if the current frame is interlaced, 0 otherwise.
* FRAME_RATE or FR: The frame rate (only defined for constant frame-rate video).
* TB: The timebase of the input timestamps. For example, 1/90000 or 1/1000.
* POS: Original byte position in the file.
* PREV_INPTS: The previous input PTS.
* PREV_INT: Previous input time in seconds.
* PREV_OUTPTS: The previous output PTS.
* PREV_OUTT: The previous output time in seconds. [3, 4, 6, 7, 8]

## Common Mathematical Functions
Your expression can also utilize mathematical functions such as min(x, y), max(x, y), sin(x), cos(x), sqrt(x), pow(x, y), and abs(x). For a complete list of operators, refer to the [FFmpeg Filters Documentation](https://ffmpeg.org/ffmpeg-filters.html). [9, 10]
## Practical Examples

* Speed up video (2x): setpts=0.5*PTS
* Slow down video (2x): setpts=2*PTS
* Shift timestamps to start at 0: setpts=PTS-STARTPTS
* Drop/Duplicate frames for specific spacing: setpts=N*TB [6, 11, 12, 13]

Could you tell me what specific effect or timing change you are trying to achieve (e.g., speed up, slow down, or sync overlays)? I can help you write the exact setpts expression you need.

[1] [https://www.youtube.com](https://www.youtube.com/watch?v=ckCuy7dmyPI&t=9)
[2] [https://trac.ffmpeg.org](https://trac.ffmpeg.org/wiki/How%20to%20speed%20up%20/%20slow%20down%20a%20video)
[3] [https://superuser.com](https://superuser.com/questions/1303337/ffmpeg-setpts-explanation)
[4] [https://ayosec.github.io](https://ayosec.github.io/ffmpeg-filters-docs/8.0/Filters/Multimedia/asetpts.html)
[5] [https://trembit.com](https://trembit.com/blog/ffmpeg-mpdecimate-filter-for-dummies/)
[6] [https://stackoverflow.com](https://stackoverflow.com/questions/58261344/what-does-ffmpegs-setpts-filter-do-exactly)
[7] [https://ayosec.github.io](https://ayosec.github.io/ffmpeg-filters-docs/8.0/Filters/Multimedia/setpts.html)
[8] [https://ayosec.github.io](https://ayosec.github.io/ffmpeg-filters-docs/8.0/Filters/Multimedia/setpts.html)
[9] [https://ffmpeg.org](https://ffmpeg.org/ffmpeg-filters.html)
[10] [https://flespi.com](https://flespi.com/kb/expressions)
[11] [https://yasint.dev](https://yasint.dev/fast-forward-videos-with-ffmpeg/)
[12] [https://gist.github.com](https://gist.github.com/0ad4880729a29f32430bb5ebbd49da41)
[13] [https://www.baeldung.com](https://www.baeldung.com/linux/ffmpeg-cutting-videos)

