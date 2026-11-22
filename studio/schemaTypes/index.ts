import type {SchemaTypeDefinition} from 'sanity'

import {propertyListing} from './propertyListing'

// The `propertyListing` schema (slug, headline, description, amenities, photos —
// SPEC §6) is owned by Agent B in the feature phase (D-005).
export const schemaTypes: SchemaTypeDefinition[] = [propertyListing]
