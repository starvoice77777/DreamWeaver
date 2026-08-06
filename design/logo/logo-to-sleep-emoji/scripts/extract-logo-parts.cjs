const fs = require("node:fs");
const path = require("node:path");
const sharp = require("sharp");

const [sourcePath, outputDirectory] = process.argv.slice(2);

if (!sourcePath || !outputDirectory) {
  throw new Error("Usage: node extract-logo-parts.cjs <source> <output-directory>");
}

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

const extract = async () => {
  const { data, info } = await sharp(sourcePath)
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const { width, height } = info;
  const foreground = new Uint8Array(width * height);

  for (let index = 0; index < width * height; index += 1) {
    const offset = index * 3;
    foreground[index] =
      data[offset] + data[offset + 1] + data[offset + 2] > 240 ? 1 : 0;
  }

  const visited = new Uint8Array(width * height);
  const queue = new Int32Array(width * height);
  const components = [];

  for (let start = 0; start < width * height; start += 1) {
    if (!foreground[start] || visited[start]) continue;

    let head = 0;
    let tail = 0;
    let count = 0;
    let minX = width;
    let minY = height;
    let maxX = 0;
    let maxY = 0;
    const pixels = [];

    queue[tail++] = start;
    visited[start] = 1;

    while (head < tail) {
      const current = queue[head++];
      const x = current % width;
      const y = Math.floor(current / width);
      count += 1;
      pixels.push(current);
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);

      const neighbors = [current - 1, current + 1, current - width, current + width];
      for (const neighbor of neighbors) {
        if (neighbor < 0 || neighbor >= width * height) continue;
        const neighborX = neighbor % width;
        const neighborY = Math.floor(neighbor / width);
        if (Math.abs(neighborX - x) + Math.abs(neighborY - y) !== 1) continue;
        if (!foreground[neighbor] || visited[neighbor]) continue;
        visited[neighbor] = 1;
        queue[tail++] = neighbor;
      }
    }

    if (count > 1000) {
      components.push({ count, minX, minY, maxX, maxY, pixels });
    }
  }

  components.sort((a, b) => a.minY - b.minY);
  if (components.length !== 3) {
    throw new Error(`Expected 3 logo components, found ${components.length}`);
  }

  fs.mkdirSync(outputDirectory, { recursive: true });
  fs.copyFileSync(sourcePath, path.join(outputDirectory, "logo-source.png"));

  const padding = 6;
  const manifest = { sourceWidth: width, sourceHeight: height, parts: [] };

  for (let partIndex = 0; partIndex < components.length; partIndex += 1) {
    const component = components[partIndex];
    const left = Math.max(0, component.minX - padding);
    const top = Math.max(0, component.minY - padding);
    const right = Math.min(width - 1, component.maxX + padding);
    const bottom = Math.min(height - 1, component.maxY + padding);
    const cropWidth = right - left + 1;
    const cropHeight = bottom - top + 1;
    const beige = Buffer.alloc(cropWidth * cropHeight * 4);
    const blue = Buffer.alloc(cropWidth * cropHeight * 4);
    const componentMask = new Uint8Array(width * height);
    for (const pixel of component.pixels) componentMask[pixel] = 1;

    for (let y = 0; y < cropHeight; y += 1) {
      for (let x = 0; x < cropWidth; x += 1) {
        const sourceX = left + x;
        const sourceY = top + y;
        const sourceOffset = (sourceY * width + sourceX) * 3;
        const targetOffset = (y * cropWidth + x) * 4;
        const isPartPixel = componentMask[sourceY * width + sourceX] === 1;
        const luminance = isPartPixel
          ? data[sourceOffset] * 0.2126 +
            data[sourceOffset + 1] * 0.7152 +
            data[sourceOffset + 2] * 0.0722
          : 0;
        const alpha = Math.round(clamp((luminance - 2) / 168, 0, 1) * 255);

        beige[targetOffset] = 195;
        beige[targetOffset + 1] = 164;
        beige[targetOffset + 2] = 122;
        beige[targetOffset + 3] = alpha;

        blue[targetOffset] = 76;
        blue[targetOffset + 1] = 145;
        blue[targetOffset + 2] = 255;
        blue[targetOffset + 3] = alpha;
      }
    }

    const name = ["top", "middle", "bottom"][partIndex];
    await sharp(beige, {
      raw: { width: cropWidth, height: cropHeight, channels: 4 },
    })
      .png()
      .toFile(path.join(outputDirectory, `z-${name}-beige.png`));
    await sharp(blue, {
      raw: { width: cropWidth, height: cropHeight, channels: 4 },
    })
      .png()
      .toFile(path.join(outputDirectory, `z-${name}-blue.png`));

    manifest.parts.push({
      name,
      left,
      top,
      width: cropWidth,
      height: cropHeight,
    });
  }

  fs.writeFileSync(
    path.join(outputDirectory, "logo-parts.json"),
    `${JSON.stringify(manifest, null, 2)}\n`,
  );
};

extract().catch((error) => {
  console.error(error);
  process.exit(1);
});
