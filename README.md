# analyze_audio

CLI tool for analyzing audio file dynamics, loudness, and spectral content. Outputs stats to terminal and generates a spectrogram PNG.

## Dependencies

- `ffmpeg`
- `ffprobe`
- `bc`

`bc` is typically pre-installed on MacOS/Linux.

For ffmpeg/ffprobe: use your favorite package manager (brew/apt/pacman/nix/etc..) to install if not already on your system.

## Usage

```bash
./main.sh <audio_file> [output_dir]
```

**Examples:**

```bash
# Output spectrogram to current directory
./main.sh my_track.wav

# Specify output directory
./main.sh ./audio/my_track.mp3 ./output
```

## Output

**Terminal:**
- File info (codec, sample rate, channels, bitrate, duration)
- Dynamics (peak level, RMS, noise floor)
- Loudness (EBU R128: integrated LUFS, true peak, LRA)
- Spectral (centroid, flatness, rolloff)

**File:**
- `<filename>_spectrogram.png` — log-scale frequency spectrogram

## Spectrogram Resolution

Default is `1920x480`. Edit `main.sh` to change:

```bash
# 4K
-lavfi "showspectrumpic=s=3840x2160:mode=combined:color=intensity:scale=log:fscale=log:legend=1"

# Wide format
-lavfi "showspectrumpic=s=3840x1080:mode=combined:color=intensity:scale=log:fscale=log:legend=1"
```

## License

MIT
