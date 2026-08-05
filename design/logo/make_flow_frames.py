from pathlib import Path
import math
import sys

import numpy as np
from PIL import Image, ImageFilter


source = Path(sys.argv[1])
output = Path(sys.argv[2])
frame_count = int(sys.argv[3])
size = 1080

output.mkdir(parents=True, exist_ok=True)
base_image = Image.open(source).convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
base = np.asarray(base_image, dtype=np.float32)
luminance = base.mean(axis=2)
stroke_mask = np.clip((luminance - 105.0) / 135.0, 0.0, 1.0)

# The projection follows the logo's existing lower-left to upper-right perspective.
yy, xx = np.mgrid[0:size, 0:size]
flow_axis = (xx - yy + size) / (2.0 * size)

for frame in range(frame_count):
    phase = frame / frame_count
    distance = np.abs(((flow_axis - phase + 0.5) % 1.0) - 0.5)
    core = np.exp(-0.5 * (distance / 0.035) ** 2)
    wake = np.exp(-0.5 * ((((flow_axis - phase - 0.055 + 0.5) % 1.0) - 0.5) / 0.075) ** 2)
    pulse = np.clip(core + 0.30 * wake, 0.0, 1.0) * stroke_mask

    # Existing white strokes become slightly brighter and warmer as the current passes.
    warm_white = np.array([255.0, 252.0, 238.0], dtype=np.float32)
    mixed = base * (1.0 - pulse[..., None] * 0.62) + warm_white * pulse[..., None] * 0.62

    # A restrained halo is derived from the same stroke pixels; no new motif is introduced.
    halo_source = Image.fromarray(np.uint8(np.clip(pulse * 255.0, 0, 255)), "L")
    halo = np.asarray(halo_source.filter(ImageFilter.GaussianBlur(radius=7)), dtype=np.float32) / 255.0
    halo_color = np.array([82.0, 102.0, 142.0], dtype=np.float32)
    mixed += halo[..., None] * halo_color * 0.11

    Image.fromarray(np.uint8(np.clip(mixed, 0, 255)), "RGB").save(
        output / f"frame-{frame:04d}.png",
        optimize=False,
    )
