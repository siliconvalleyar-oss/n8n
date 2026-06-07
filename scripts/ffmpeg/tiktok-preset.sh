#!/bin/sh
# tiktok-preset.sh — Apply TikTok-optimized FFmpeg preset
# Usage: sh tiktok-preset.sh <input> <output> [width] [height] [fps]
#
# This applies the standard TikTok pipeline:
#   1. Scale to 9:16 (1080x1920)
#   2. Add vertical crop if needed
#   3. Optimize bitrate for short-form
#   4. Add audio normalization

INPUT="${1:?Missing input path}"
OUTPUT="${2:?Missing output path}"
WIDTH="${3:-1080}"
HEIGHT="${4:-1920}"
FPS="${5:-30}"

exec ffmpeg -i "$INPUT" \
    -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:black" \
    -r "$FPS" \
    -c:v libx264 \
    -preset medium \
    -crf 23 \
    -b:v 4000k \
    -maxrate 4000k \
    -bufsize 8000k \
    -profile:v high \
    -level:v 4.2 \
    -pix_fmt yuv420p \
    -c:a aac \
    -b:a 128k \
    -af "loudnorm=I=-14:LRA=1:TP=-1" \
    -movflags +faststart \
    -y "$OUTPUT"
