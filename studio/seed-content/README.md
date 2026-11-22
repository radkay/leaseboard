# Sanity seed content

Importable placeholder content for the three seeded properties — **not** applied
automatically. Ron imports it once during deploy (see `docs/DEPLOY.md`).

## Files

| File | What it is |
|---|---|
| `listings.ndjson` | Three `propertyListing` documents (one per property) in Sanity's import format. |
| `images/*.png` | Generated placeholder building images (no stock photos). |
| `generate-images.mjs` | Regenerates the PNGs from scratch using Node's built-in `zlib` — no dependencies. |
| `generate-ndjson.mjs` | Regenerates `listings.ndjson`. |

## Slugs are the join key

Each document's `slug.current` matches `properties.sanity_slug` in the Rails seed
(`apps/admin/db/seeds.rb`: the property name, lower-cased, non-alphanumerics → `-`):

- Maple Court → `maple-court`
- Riverside Lofts → `riverside-lofts`
- Oakwood Flats → `oakwood-flats`

The public Rails page looks a listing up by this slug, so the slugs must stay in
sync with the seed. The copy and amenities are deliberately fictional placeholders.

## Regenerate

```sh
cd studio/seed-content
node generate-images.mjs    # writes images/*.png
node generate-ndjson.mjs    # writes listings.ndjson
```

## Import

See `docs/DEPLOY.md`. In short, from `studio/`:

```sh
npx sanity dataset import seed-content/listings.ndjson production --replace
```

The asset paths in `listings.ndjson` are relative to this folder, which is where
the import tool resolves them from (it uses the NDJSON file's directory as the
asset base).
