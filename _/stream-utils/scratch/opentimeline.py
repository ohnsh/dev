import opentimelineio as otio

# 1. Load your exported FCPXML timeline file
timeline_path = "your_timeline.fcpxml"
timeline = otio.adapters.read_from_file(timeline_path)

# 2. Open your output FFmpeg playlist file
with open("ffmpeg_playlist.txt", "w") as f:

    # Target the video track (usually the first video track)
    video_tracks = [t for t in timeline.tracks if t.kind == otio.schema.TrackKind.Video]

    if not video_tracks:
        print("No video tracks found.")
        exit()

    main_track = video_tracks[0]

    for item in main_track:
        # Verify the timeline object is a playable media clip
        if isinstance(item, otio.schema.Clip):
            # Extract the raw file path/URI
            media_reference = item.media_reference
            if hasattr(media_reference, 'target_url') and media_reference.target_url:
                file_path = media_reference.target_url.replace("file://", "")

                # Fetch clip trim bounds (in frames/rates)
                source_range = item.source_range

                if source_range:
                    # Convert NLE timecode boundaries into pure seconds
                    in_seconds = source_range.start_time.to_seconds()
                    duration_seconds = source_range.duration.to_seconds()
                    out_seconds = in_seconds + duration_seconds

                    # Write clean syntax straight to the concat text file
                    f.write(f"file '{file_path}'\n")
                    f.write(f"inpoint {in_seconds:.3f}\n")
                    f.write(f"outpoint {out_seconds:.3f}\n\n")

print("FFmpeg playlist compiled successfully to 'ffmpeg_playlist.txt'!")

