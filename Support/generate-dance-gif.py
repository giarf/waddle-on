"""Export the original 193-frame dance for the README (requires Pillow)."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
atlas = Image.open(ROOT / "Sources/WaddleOn/Resources/Penguin/penguin-dance-atlas.png").convert("RGBA")
frames = []
for index in range(193):
    x, y = index % 16 * 226, index // 16 * 213
    rgba = atlas.crop((x, y, x + 226, y + 213))
    frame = rgba.convert("RGB").quantize(colors=255)
    frame.putpalette(frame.getpalette()[:765] + [0, 0, 0])
    frame.paste(255, mask=rgba.getchannel("A").point(lambda alpha: 255 if alpha < 128 else 0))
    frames.append(frame)

# GIF uses 10 ms ticks: distribute 40/50 ms delays to preserve 24 fps.
durations = [10 * (round((i + 1) * 100 / 24) - round(i * 100 / 24)) for i in range(193)]
frames[0].save(ROOT / "docs/penguin-dance.gif", save_all=True,
               append_images=frames[1:], duration=durations, loop=0,
               transparency=255, disposal=2, optimize=False)
