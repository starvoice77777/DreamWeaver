from pathlib import Path
import sys

from PIL import Image, ImageDraw


frames = Path(sys.argv[1])
output = Path(sys.argv[2])
indices = [0, 20, 40, 60, 80, 100]
thumb_size = 360
sheet = Image.new("RGB", (thumb_size * 3, thumb_size * 2), (4, 8, 24))

for slot, index in enumerate(indices):
    frame = Image.open(frames / f"frame-{index:04d}.png").convert("RGB")
    frame.thumbnail((thumb_size, thumb_size), Image.Resampling.LANCZOS)
    x = (slot % 3) * thumb_size
    y = (slot // 3) * thumb_size
    sheet.paste(frame, (x, y))
    ImageDraw.Draw(sheet).text((x + 14, y + 14), f"{index / 30:.1f}s", fill=(170, 180, 205))

sheet.save(output)
