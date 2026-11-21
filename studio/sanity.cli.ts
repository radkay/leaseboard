import {defineCliConfig} from 'sanity/cli'

// The CLI reads the same project id as the studio config. It is provided by the
// environment (studio/.env.local locally); no project id is committed.
export default defineCliConfig({
  api: {
    projectId: process.env.SANITY_STUDIO_PROJECT_ID,
    dataset: process.env.SANITY_STUDIO_DATASET || 'production',
  },
})
