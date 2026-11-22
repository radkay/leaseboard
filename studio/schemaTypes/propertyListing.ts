import {defineArrayMember, defineField, defineType} from 'sanity'

// The marketing listing for one property. Edited here, read by the public Rails
// page over GROQ (SPEC §6). The `slug` is the join key back to Postgres: it must
// equal the owning property's `properties.sanity_slug`. Rails owns that column;
// Studio never writes it, so the match is enforced by the editor entering the
// right value, not by a reference.
export const propertyListing = defineType({
  name: 'propertyListing',
  title: 'Property listing',
  type: 'document',
  fields: [
    defineField({
      name: 'slug',
      title: 'Slug',
      description:
        'Must match the property’s sanity_slug in the admin database. This is how the ' +
        'public page finds this listing.',
      type: 'slug',
      // No `source`: the slug is a stable external key, not derived from the
      // headline, so it is entered by hand and must not drift when the headline
      // is edited.
      validation: (rule) => rule.required(),
    }),
    defineField({
      name: 'headline',
      title: 'Headline',
      type: 'string',
      validation: (rule) => rule.required().max(120),
    }),
    defineField({
      name: 'description',
      title: 'Description',
      description: 'Marketing copy shown on the public listing page.',
      type: 'array',
      of: [defineArrayMember({type: 'block'})],
    }),
    defineField({
      name: 'amenities',
      title: 'Amenities',
      type: 'array',
      of: [defineArrayMember({type: 'string'})],
      options: {layout: 'tags'},
    }),
    defineField({
      name: 'photos',
      title: 'Photos',
      type: 'array',
      of: [
        defineArrayMember({
          type: 'image',
          options: {hotspot: true},
          fields: [
            defineField({
              name: 'alt',
              title: 'Alternative text',
              description: 'Describes the photo for screen readers and when the image fails to load.',
              type: 'string',
              validation: (rule) => rule.required(),
            }),
          ],
        }),
      ],
    }),
  ],
  preview: {
    select: {title: 'headline', subtitle: 'slug.current', media: 'photos.0'},
  },
})
