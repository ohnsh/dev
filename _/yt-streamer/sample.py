import os
import subprocess
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

# 1. Authenticate with YouTube
SCOPES = ['https://www.googleapis.com/auth/youtube.force-ssl']
flow = InstalledAppFlow.from_client_secrets_file('client_secrets.json', SCOPES)
credentials = flow.run_local_server(port=0)
youtube = build('youtube', 'v3', credentials=credentials)

# 2. Insert/Create a Live Broadcast
broadcast_response = youtube.liveBroadcasts().insert(
    part="snippet,status",
    body={
      "snippet": {"title": "My Automated FFmpeg Stream"},
      "status": {"privacyStatus": "public", "selfDeclaredMadeForKids": False}
    }
).execute()

# 3. Create the Live Stream configuration (This generates the ingestion address)
stream_response = youtube.liveStreams().insert(
    part="cdn,snippet",
    body={
      "cdn": {"frameRate": "30fps", "ingestionType": "rtmp", "resolution": "1080p"},
      "snippet": {"title": "FFmpeg Stream Config"}
    }
).execute()

# 4. Bind them together
youtube.liveBroadcasts().bind(
    id=broadcast_response['id'],
    streamId=stream_response['id']
).execute()

# 5. Extract the RTMP URL and Stream Key
ingestion_info = stream_response['cdn']['ingestionInfo']
rtmp_url = ingestion_info['ingestionAddress']
stream_key = ingestion_info['streamName']
full_target_url = f"{rtmp_url}/{stream_key}"

# 6. Hand off to FFmpeg
ffmpeg_cmd = [
    'ffmpeg', '-re', '-i', 'your_input_source.mp4',
    '-c:v', 'libx264', '-preset', 'veryfast', '-b:v', '4500k',
    '-c:a', 'aac', '-b:a', '128k', '-f', 'flv', full_target_url
]

subprocess.run(ffmpeg_cmd)
