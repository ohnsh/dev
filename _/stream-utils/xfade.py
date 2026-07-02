#!/usr/bin/env python3

import json
import subprocess
import sys
from pathlib import Path

# --- CONFIGURATION ---
# video_files = [f"{item}" for item in Path('out-segments').iterdir()]
video_files = sys.argv[1:]
output_file = "output_playlist.mp4"
fade_duration = 0.25  # Crossfade duration in seconds
# ---------------------

if len(video_files) < 2:
    print("You need at least 2 videos to crossfade.")
    sys.exit(1)


def get_duration(filename):
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1",
        filename,
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, text=True)
    return float(result.stdout.strip().split("=")[1])


# Gather all durations
durations = [get_duration(f) for f in video_files]

# Build the filter_complex string
filter_graph = ""
inputs = ""

# Inputs look like: -i video1.mp4 -i video2.mp4 ...
for f in video_files:
    inputs += f"-i {f} "

# Initialize the first video track names
current_v = "[0:v]"
current_a = "[0:a]"

offset = durations[0]

for i in range(1, len(video_files)):
    # Calculate crossfade start time
    offset = offset - fade_duration

    # Video crossfade
    next_v = f"[v_mix_{i}]"
    filter_graph += (
        f"{current_v}[{i}:v]xfade=transition=fade:duration={fade_duration}:offset={offset}{next_v}; "
    )
    current_v = next_v

    # Audio crossfade
    next_a = f"[a_mix_{i}]"
    filter_graph += f"{current_a}[{i}:a]acrossfade=duration={fade_duration}{next_a}; "
    current_a = next_a

    # Update offset for the next iteration
    offset += durations[i]

# Clean up trailing semicolons
filter_graph = filter_graph.strip().rstrip(";")

# Construct full command
ffmpeg_cmd = (
    f"ffmpeg {inputs}-filter_complex \"{filter_graph}\" "
    f'-map "{current_v}" -map "{current_a}" -c:v libx264 -c:a aac {output_file}'
)

print("Generated FFmpeg Command:\n")
print(ffmpeg_cmd)

# Uncomment the line below to run it automatically:
subprocess.run(ffmpeg_cmd, shell=True)
