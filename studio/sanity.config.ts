import {defineConfig} from 'sanity'
import {structureTool} from 'sanity/structure'

import {schemaTypes} from './schemaTypes'

// The project id is supplied per environment, never committed. Locally, set it
// in studio/.env.local (SANITY_STUDIO_PROJECT_ID=...); on the hosted studio it
// comes from the deploy environment. No Sanity project exists yet, so a build
// without the variable set falls back to a placeholder: `sanity build` only
// bundles the studio and does not contact the project.
const projectId = process.env.SANITY_STUDIO_PROJECT_ID || 'placeholder'
const dataset = process.env.SANITY_STUDIO_DATASET || 'production'

export default defineConfig({
  name: 'default',
  title: 'Leaseboard',

  projectId,
  dataset,

  plugins: [structureTool()],

  schema: {
    types: schemaTypes,
  },
})
