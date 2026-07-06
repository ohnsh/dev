# new versions can generate .srt tracks using OpenAI Whisper

ffmpeg -hide_banner -i input.mp4 -af "silencedetect=noise=-30dB:d=0.5" -f null - 2>&1 | grep -o -E "silence_start: [0-9.]+|silence_end: [0-9.]+"

ffmpeg -i input.mp4 -af "silenceremove=start_periods=1:start_silence=30dB:start_duration=0.5:stop_periods=1:stop_silence=30dB:stop_duration=0.5" output.mp4
