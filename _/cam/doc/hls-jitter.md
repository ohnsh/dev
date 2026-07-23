You are seeing this warning because **Low-Latency HLS (LL-HLS)** requires strict consistency in segment and partial-segment durations, and iOS clients (AVPlayer/Safari) are notoriously strict about standard violations.

---

## What the Error Means

In LL-HLS, media segments are broken down into micro-chunk "parts" (e.g., ~200–300ms each).

MediaMTX calculates and advertises a target part duration (e.g., `EXT-X-PART-INF:TARGET=0.242`) in its HLS playlist. According to the Apple LL-HLS specification:

* The **actual duration** of any individual part **must not exceed** the target duration.
* If a part's actual duration strays too far from expectations or grows larger than the target, MediaMTX has to dynamically resize the advertised target duration.

When MediaMTX updates this target duration on the fly (e.g., from 242ms to 239ms or vice versa), Apple's `AVPlayer` engine on iOS will often freeze, buffer endlessly, or reject the stream outright.

---

## Why Is This Happening?

The root cause is almost always **inconsistent timestamps, variable frame rates, or keyframe (GOP) gaps** coming from your input stream (RTSP, RTMP, WebRTC, etc.).

1. **Inconsistent Source Timestamps / Jitter:**
If your encoder/camera is outputting frames with variable frame timing or frame delays over the network, frame intervals fluctuate (e.g., 239ms vs 242ms worth of media frames per slice).
2. **Variable Keyframe Interval (GOP Size):**
MediaMTX splits segments based on video Keyframes (I-frames). If keyframe distances drift, the resulting part/segment durations fluctuate.
3. **Proxy or Timestamps Replaced by Arrival Time:**
If the stream passes through an intermediate proxy (like GStreamer or FFmpeg) that overrides original presentation timestamps (PTS) with wall-clock arrival time, network jitter directly causes timestamp instability.

---

## How to Fix It

### 1. Adjust `hlsPartDuration` in MediaMTX

In your `mediamtx.yml` config, try increasing the configured part duration slightly to give the muxer more head room:

```yaml
# Default is often 200ms or calculated automatically. 
# Increasing it (e.g. 500ms or 1s) reduces sensitivity to tiny frame timing fluctuations.
hlsPartDuration: 500ms

```

### 2. Fix the Source Encoder Settings (Most Effective)

Ensure the camera or software feeding MediaMTX has stable encoding settings:

* **Constant Frame Rate (CFR):** Avoid Variable Frame Rate (VFR).
* **Fixed Keyframe Interval (GOP):** Set a strict I-frame interval (e.g., keyframe every 1 or 2 seconds / GOP of 30 or 60 at 30fps).
* **Disable "Smart/Intelligent" Codecs:** Features like Hikvision "Smart264" or Dahua "Smart Codec" dynamically shift keyframes, which breaks strict HLS segmenting.

### 3. Disable Low-Latency HLS (If Low Latency isn't Required)

If you don't need sub-second latency and standard 2–4 second HLS delay is fine, you can turn off low-latency mode. Standard HLS handles duration shifts much more gracefully on iOS.

```yaml
hlsVariant: mpegts # or fmp4 without LL-HLS features

```
