font=/usr/share/fonts/dejavu/DejaVuSans.ttf

# picking dejavu sans completely randomly.
[[ -e $font ]] || font=$HOME/Library/Fonts/DejaVuSans.ttf

title() {
  # d = duration, r = framerate
  ffmpeg -f lavfi -i "color=color=#1a1a2e:s=1920x1080:d=5:r=30" \
    -vf "drawtext=fontfile=$font:text='STREAM STARTING SOON':fontcolor=white:fontsize=72:x=(w-text_w)/2:y=(h-text_h)/2" \
    -c:v libx264 -pix_fmt yuv420p -g 60 title_card.mp4
}

title_gradient() {
  ffmpeg -f lavfi -i "nullsrc=s=1920x1080:d=5:r=30" \
    -vf "geq=r='X/W*255':g='0':b='Y/H*255', gblur=sigma=100,
     drawtext=fontfile=$font:text='LIVE STREAMING':fontcolor=white:fontsize=64:x=(w-text_w)/2:y=(h-text_h)/2" \
    -c:v libx264 -pix_fmt yuv420p -g 60 title_card.mp4
}

title_retro() {
  ffmpeg -f lavfi -i "smptebars=s=1920x1080:d=5:r=30" \
    -vf "drawtext=fontfile=$font:text='INITIALIZING FEED...':fontcolor=white:box=1:boxcolor=black@0.8:boxborderw=20:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2" \
    -c:v libx264 -pix_fmt yuv420p -g 60 title_card.mp4
}

title_silent_audio() {
  # e.g. youtube requires an audio track
  ffmpeg -f lavfi -i "color=color=#222222:s=1920x1080:d=5:r=30" -f lavfi -i "anullsrc=cl=stereo:r=44100" \
    -vf "drawtext=fontfile=font.ttf:text='Stream Launching':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2" \
    -c:v libx264 -c:a aac -pix_fmt yuv420p -g 60 title_card.mp4
}

title_bgimage() {
  # -r and -g are for RTMP stability (match subsequent inputs)
  ffmpeg -loop 1 -i background.png -t 5 \
    -vf "drawtext=fontfile=$font:text='STREAM STARTING SOON':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2,
     drawtext=fontfile=$font:text='%{localtime\:%X}':fontcolor=yellow:fontsize=32:x=(w-text_w)/2:y=(h-text_h)/2+60" \
    -c:v libx264 -pix_fmt yuv420p -r 30 -g 60 title_card.mp4
}

# Variable,Description,Example Output
# %{localtime\:%a %b %d %Y},Current date,Thu Jul 02 2026
# %{localtime\:%I\:%M %p},12-hour time with AM/PM,04:02 AM
# %{pts\:hms},Time elapsed in the video,00:00:03
# textfile='live_title.txt',Pulls text from a local file,(Updates if the file changes)
