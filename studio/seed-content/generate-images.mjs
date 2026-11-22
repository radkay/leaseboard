// Generates the placeholder listing images from scratch — solid vector-ish
// scenes encoded as PNG using only Node's built-in `zlib`. No stock photos, no
// downloads, no dependencies. Re-run with: `node generate-images.mjs`.
//
// Each property gets two simple building scenes in its own palette. They exist
// only so the Sanity listings have real image assets to import; Ron can swap in
// real photography later.

import { deflateSync } from "node:zlib";
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const OUT = join(dirname(fileURLToPath(import.meta.url)), "images");
const WIDTH = 1200;
const HEIGHT = 800;

// --- Minimal PNG encoder (8-bit RGB) ---------------------------------------

const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  return table;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const typeBuf = Buffer.from(type, "ascii");
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])));
  return Buffer.concat([len, typeBuf, data, crc]);
}

function encodePng(width, height, pixelAt) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // colour type: truecolour (RGB)

  const raw = Buffer.alloc((width * 3 + 1) * height);
  let p = 0;
  for (let y = 0; y < height; y++) {
    raw[p++] = 0; // filter: none
    for (let x = 0; x < width; x++) {
      const [r, g, b] = pixelAt(x, y);
      raw[p++] = r;
      raw[p++] = g;
      raw[p++] = b;
    }
  }

  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr),
    chunk("IDAT", deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

// --- Scene -----------------------------------------------------------------

const mix = (a, b, t) => a.map((v, i) => Math.round(v + (b[i] - v) * t));

// A flat building scene: sky gradient, a ground band, one façade with a window
// grid. `shift` nudges the façade so the two images per property differ.
function scene({ sky, skyTop, ground, facade, window: win }, shift) {
  const groundY = HEIGHT * 0.78;
  const bx0 = WIDTH * (0.28 + shift);
  const bx1 = WIDTH * (0.72 + shift);
  const by0 = HEIGHT * 0.3;

  return (x, y) => {
    if (y >= groundY) return ground;

    const inFacade = x >= bx0 && x < bx1 && y >= by0;
    if (inFacade) {
      // 6 x 4 window grid inset into the façade.
      const u = (x - bx0) / (bx1 - bx0);
      const v = (y - by0) / (groundY - by0);
      const cell = 0.12;
      const gx = (u % (1 / 6)) * 6;
      const gy = (v % (1 / 4)) * 4;
      const onWindow = gx > cell && gx < 1 - cell && gy > cell && gy < 1 - cell;
      return onWindow ? win : facade;
    }

    return mix(skyTop, sky, y / groundY); // sky gradient, lighter toward horizon
  };
}

const PALETTES = {
  "maple-court": {
    sky: [214, 232, 223],
    skyTop: [120, 170, 150],
    ground: [36, 78, 60],
    facade: [45, 106, 79],
    window: [226, 240, 233],
  },
  "riverside-lofts": {
    sky: [214, 226, 240],
    skyTop: [120, 150, 190],
    ground: [26, 54, 92],
    facade: [29, 78, 137],
    window: [226, 236, 246],
  },
  "oakwood-flats": {
    sky: [240, 230, 216],
    skyTop: [190, 160, 120],
    ground: [92, 62, 40],
    facade: [127, 85, 57],
    window: [244, 236, 226],
  },
};

mkdirSync(OUT, { recursive: true });

for (const [slug, palette] of Object.entries(PALETTES)) {
  for (const [idx, shift] of [-0.04, 0.04].entries()) {
    const file = join(OUT, `${slug}-${idx + 1}.png`);
    writeFileSync(file, encodePng(WIDTH, HEIGHT, scene(palette, shift)));
    console.log(`wrote ${file}`);
  }
}
