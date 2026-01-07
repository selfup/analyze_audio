#!/bin/bash

# main.sh - Analyze audio file dynamics, loudness, and spectral content
# Dependencies: ffmpeg, ffprobe, bc
# Usage: ./main.sh <audio_file> [output_dir]

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <audio_file> [output_dir]"
    exit 1
fi

INPUT="$1"
FILENAME=$(basename "$INPUT")
BASENAME="${FILENAME%.*}"
OUTPUT_DIR="${2:-.}"

if [ ! -f "$INPUT" ]; then
    echo "Error: File not found: $INPUT"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "AUDIO ANALYSIS: $FILENAME"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# --- File Info ---
echo "▸ FILE INFO"
echo "───────────────────────────────────────────────────────────────"
ffprobe -v quiet -show_entries format=duration,bit_rate:stream=sample_rate,channels,codec_name \
    -of default=noprint_wrappers=1 "$INPUT" | while read line; do
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
        codec_name)   printf "  Codec:       %s\n" "$val" ;;
        sample_rate)  printf "  Sample Rate: %s Hz\n" "$val" ;;
        channels)     printf "  Channels:    %s\n" "$val" ;;
        bit_rate)     printf "  Bitrate:     %s kbps\n" "$((val / 1000))" ;;
        duration)     printf "  Duration:    %.2f sec\n" "$val" ;;
    esac
done
echo ""

# --- Dynamics ---
echo "▸ DYNAMICS"
echo "───────────────────────────────────────────────────────────────"
ffmpeg -i "$INPUT" -af "astats=measure_overall=all:measure_perchannel=none" -f null - 2>&1 | \
    grep -E "Peak level dB|RMS level dB|Crest factor|Noise floor dB|Dynamic range" | \
    sed 's/\[Parsed_astats_0.*\] /  /'
echo ""

# --- Loudness (EBU R128) ---
echo "▸ LOUDNESS (EBU R128)"
echo "───────────────────────────────────────────────────────────────"
ffmpeg -i "$INPUT" -af "loudnorm=print_format=summary" -f null - 2>&1 | \
    grep -E "Input Integrated|Input True Peak|Input LRA|Input Threshold" | \
    sed 's/^/  /'
echo ""

# --- Spectral Stats (averaged) ---
echo "▸ SPECTRAL (sample)"
echo "───────────────────────────────────────────────────────────────"
SPECTRAL=$(ffmpeg -i "$INPUT" -t 10 -af "aspectralstats=measure=centroid+spread+flatness+rolloff,ametadata=print" -f null - 2>&1 | \
    grep "lavfi.aspectralstats.1" | head -20)

centroid_sum=0
flatness_sum=0
rolloff_sum=0
count=0

while IFS= read -r line; do
    if [[ "$line" == *"centroid"* ]]; then
        val=$(echo "$line" | sed 's/.*=//')
        centroid_sum=$(echo "$centroid_sum + $val" | bc -l)
        ((count++)) || true
    elif [[ "$line" == *"flatness"* ]]; then
        val=$(echo "$line" | sed 's/.*=//')
        flatness_sum=$(echo "$flatness_sum + $val" | bc -l)
    elif [[ "$line" == *"rolloff"* ]]; then
        val=$(echo "$line" | sed 's/.*=//')
        rolloff_sum=$(echo "$rolloff_sum + $val" | bc -l)
    fi
done <<< "$SPECTRAL"

if [ "$count" -gt 0 ]; then
    printf "  Spectral Centroid: %.1f Hz (brightness)\n" "$(echo "$centroid_sum / $count" | bc -l)"
    printf "  Spectral Flatness: %.3f (0=tonal, 1=noise)\n" "$(echo "$flatness_sum / $count" | bc -l)"
    printf "  Spectral Rolloff:  %.1f Hz (high freq extent)\n" "$(echo "$rolloff_sum / $count" | bc -l)"
fi
echo ""

# --- Generate Spectrogram ---
SPECTROGRAM="$OUTPUT_DIR/${BASENAME}_spectrogram.png"
echo "▸ GENERATING SPECTROGRAM"
echo "───────────────────────────────────────────────────────────────"
ffmpeg -y -v quiet -i "$INPUT" \
    -lavfi "showspectrumpic=s=1920x480:mode=combined:color=intensity:scale=log:fscale=log:legend=1" \
    "$SPECTROGRAM"
echo "  Saved: $SPECTROGRAM"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "ANALYSIS COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
