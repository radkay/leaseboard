# Deploy runbook

Ron's step-by-step for bringing Leaseboard up on Render and loading content.

> **Status.** This runbook is being assembled over several PRs. The Render
> Blueprint steps (create the Blueprint, set secrets, run the Rails seed) are
> added by the deploy-blueprint PR. The **Sanity content import** below is
> complete and standalone.

## Import the Sanity listing content

Loads the three `propertyListing` documents (one per seeded property) and their
placeholder images into the Studio's dataset. Run this **once**, after the Rails
seed has created the properties (the slugs must match) — content and database are
independent, so the order between them doesn't otherwise matter.

Prerequisites:

- A Sanity project and dataset (e.g. `production`) exist, and the Studio is
  configured with the project id (`studio/.env.local` locally, or the deploy
  environment).
- You're authenticated: `npx sanity login`, or set `SANITY_AUTH_TOKEN` to a
  token with write access to the dataset.

From the `studio/` directory:

```sh
# Dry run first — validates the documents and asset references without writing:
npx sanity dataset import seed-content/listings.ndjson production --replace --dry-run

# Then the real import:
npx sanity dataset import seed-content/listings.ndjson production --replace
```

Notes:

- `--replace` upserts by document id (`listing-<slug>`), so re-running is safe
  and idempotent.
- The image paths in `listings.ndjson` are relative to `seed-content/`, which is
  where the import tool resolves assets from (it uses the NDJSON file's directory
  as the asset base). Run the command from `studio/` exactly as above.
- To regenerate the content first, see `studio/seed-content/README.md`.

After importing, the public listing page for each property renders its headline,
description, amenities and photos; the live available-unit count still comes from
Postgres.
