// Builds listings.ndjson — one `propertyListing` document per seeded property,
// in Sanity's import (newline-delimited JSON) format. Run after the images exist:
//   node generate-ndjson.mjs
//
// Slugs MUST match properties.sanity_slug from the Rails seed
// (apps/admin/db/seeds.rb: name.downcase with non-alphanumerics → "-").
// Copy and amenities are deliberately fictional placeholders.
//
// Photos reference the local PNGs with Sanity's `_sanityAsset` syntax; the import
// tool uploads each file and rewrites it to an asset reference. Paths are relative
// to this NDJSON file, so run the import from this directory (see docs/DEPLOY.md).

import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));

const para = (key, text) => ({
  _type: "block",
  _key: key,
  style: "normal",
  markDefs: [],
  children: [{ _type: "span", _key: `${key}s`, text, marks: [] }],
});

const photo = (key, slug, n, alt) => ({
  _type: "image",
  _key: key,
  _sanityAsset: `image@./images/${slug}-${n}.png`,
  alt,
});

const listings = [
  {
    slug: "maple-court",
    headline: "Maple Court — garden apartments on a quiet, tree-lined street",
    description: [
      para(
        "mc1",
        "Maple Court is a fictional 60-home community built around a planted courtyard. Studios through two-bedrooms open onto green space, a short walk from cafés and the park.",
      ),
      para(
        "mc2",
        "Interiors pair in-unit laundry with generous light. Placeholder copy — replace before launch.",
      ),
    ],
    amenities: ["In-unit laundry", "Courtyard garden", "Covered parking", "Pet friendly", "Bike storage"],
    photos: [
      photo("mcp1", "maple-court", 1, "Maple Court façade with a window grid above a planted courtyard"),
      photo("mcp2", "maple-court", 2, "A second view of the Maple Court building from the garden side"),
    ],
  },
  {
    slug: "riverside-lofts",
    headline: "Riverside Lofts — open-plan living by the water",
    description: [
      para(
        "rl1",
        "Riverside Lofts is a fictional conversion of 50 light-filled homes on the waterfront, with floor-to-ceiling windows and a shared rooftop deck.",
      ),
      para(
        "rl2",
        "Open layouts suit remote work and entertaining alike. Placeholder copy — replace before launch.",
      ),
    ],
    amenities: ["Floor-to-ceiling windows", "Rooftop deck", "Fitness center", "Package lockers", "EV charging"],
    photos: [
      photo("rlp1", "riverside-lofts", 1, "Riverside Lofts exterior with tall windows against an evening sky"),
      photo("rlp2", "riverside-lofts", 2, "A second view of the Riverside Lofts building near the water"),
    ],
  },
  {
    slug: "oakwood-flats",
    headline: "Oakwood Flats — warm, modern flats near the park",
    description: [
      para(
        "ow1",
        "Oakwood Flats is a fictional set of 40 warm, modern homes with hardwood floors and updated kitchens, a block from the neighborhood park.",
      ),
      para(
        "ow2",
        "A quiet building with a dog run and secure entry. Placeholder copy — replace before launch.",
      ),
    ],
    amenities: ["Hardwood floors", "Updated kitchens", "On-site laundry", "Dog run", "Secure entry"],
    photos: [
      photo("owp1", "oakwood-flats", 1, "Oakwood Flats façade with a window grid in warm tones"),
      photo("owp2", "oakwood-flats", 2, "A second view of the Oakwood Flats building near the park"),
    ],
  },
];

const docs = listings.map((l) => ({
  _id: `listing-${l.slug}`,
  _type: "propertyListing",
  slug: { _type: "slug", current: l.slug },
  headline: l.headline,
  description: l.description,
  amenities: l.amenities,
  photos: l.photos,
}));

const ndjson = docs.map((d) => JSON.stringify(d)).join("\n") + "\n";
const out = join(HERE, "listings.ndjson");
writeFileSync(out, ndjson);
console.log(`wrote ${out} (${docs.length} documents)`);
