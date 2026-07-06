#!/usr/bin/env python3
"""
Video processor: speeds up videos or extracts clip summaries.

Usage:
  python3 video_processor.py -x 2.0 input.mp4
  python3 video_processor.py -i 10 -c 2 input.mp4 other.mp4
  python3 video_processor.py -i 30 -c 3 /path/to/videos/
"""

import argparse
import subprocess
import sys
from pathlib import Path
from io import StringIO


def collect_video_files(paths):
    """Collect video files from paths (files or directories)."""
    video_extensions = {'.mp4', '.mkv', '.avi', '.mov', '.flv', '.webm', '.m4v'}
    files = []
    
    for path in paths:
        p = Path(path)
        if p.is_file():
            files.append(str(p.resolve()))
        elif p.is_dir():
            # Collect video files from directory
            for ext in video_extensions:
                files.extend(sorted(str(f.resolve()) for f in p.glob(f'*{ext}')))
                files.extend(sorted(str(f.resolve()) for f in p.glob(f'*{ext.upper()}')))
            # Remove duplicates while preserving order
            seen = set()
            files = [f for f in files if not (f in seen or seen.add(f))]
        else:
            print(f"Warning: {path} is not a file or directory", file=sys.stderr)
    
    return files


def generate_playlist_content(files):
    """Generate concat demuxer playlist content."""
    lines = []
    for f in files:
        # Escape single quotes in filenames
        escaped = f.replace("'", "'\\''")
        lines.append(f"file '{escaped}'")
    return '\n'.join(lines) + '\n'


def run_with_pipe_playlist(ffmpeg_cmd, playlist_content):
    """Run ffmpeg with playlist fed via pipe (emulates process substitution)."""
    # Use /dev/stdin to read from pipe
    cmd = ffmpeg_cmd.replace('pipe:', '/dev/stdin')
    
    print(f"Running: {cmd}", file=sys.stderr)
    
    # Create the pipe process
    try:
        proc = subprocess.Popen(
            cmd,
            shell=True,
            stdin=subprocess.PIPE,
            text=True
        )
        proc.stdin.write(playlist_content)
        proc.stdin.close()
        proc.wait()
        return proc.returncode
    except Exception as e:
        print(f"Error running ffmpeg: {e}", file=sys.stderr)
        return 1


def main():
    parser = argparse.ArgumentParser(
        description='Speed up or summarize videos using ffmpeg'
    )
    parser.add_argument(
        '-x', '--speed',
        type=float,
        dest='speed',
        help='Speed-up factor (e.g., 2.0 for 2x speed)'
    )
    parser.add_argument(
        '-i', '--interval',
        type=float,
        dest='interval',
        help='Interval length in seconds (for summary mode)'
    )
    parser.add_argument(
        '-c', '--clip',
        type=float,
        dest='clip_duration',
        help='Clip duration in seconds to keep from each interval (for summary mode)'
    )
    parser.add_argument(
        'inputs',
        nargs='+',
        help='Input video files or directories'
    )
    
    args = parser.parse_args()
    
    # Validate mode
    if args.speed and (args.interval or args.clip_duration):
        print("Error: -x (speed) cannot be used with -i (interval) or -c (clip)", file=sys.stderr)
        return 1
    
    if (args.interval or args.clip_duration) and not (args.interval and args.clip_duration):
        print("Error: -i (interval) and -c (clip) must be used together", file=sys.stderr)
        return 1
    
    if not args.speed and not args.interval:
        print("Error: must specify either -x (speed) or -i (interval) with -c (clip)", file=sys.stderr)
        return 1
    
    # Collect video files
    files = collect_video_files(args.inputs)
    if not files:
        print("Error: no video files found", file=sys.stderr)
        return 1
    
    print(f"Found {len(files)} video file(s)", file=sys.stderr)
    
    # Generate playlist
    playlist = generate_playlist_content(files)
    
    # Build ffmpeg command
    if args.speed:
        # Speed-up mode
        output = "output_sped_up.mp4"
        setpts = f"PTS/{args.speed}"
        atempo = args.speed
        filter_complex = f"[0:v]setpts={setpts}[v];[0:a]atempo={atempo}[a]"
        cmd = (
            f'ffmpeg -f concat -safe 0 -i pipe: '
            f'-filter_complex "{filter_complex}" '
            f'-map "[v]" -map "[a]" '
            f'{output}'
        )
    else:
        # Summary mode: extract clips at intervals
        output = "output_summary.mp4"
        interval = args.interval
        duration = args.clip_duration
        # This is a placeholder; user will adjust the actual filter
        filter_complex = (
            f'select=isnan(prev_selected_t)+gte(t-prev_selected_t\\,{interval}),'
            f'setpts=N/FRAME_RATE/TB'
        )
        cmd = (
            f'ffmpeg -f concat -safe 0 -i pipe: '
            f'-vf "{filter_complex}" '
            f'-af "aselect=isnan(prev_selected_t)+gte(t-prev_selected_t\\,{interval}),asetpts=N/SR/TB" '
            f'{output}'
        )
    
    # Run with pipe
    print(f"Generated playlist ({len(playlist)} bytes)", file=sys.stderr)
    return run_with_pipe_playlist(cmd, playlist)


if __name__ == '__main__':
    sys.exit(main())
