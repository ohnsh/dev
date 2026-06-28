import { z } from 'zod'

export const daySchema = z.object({
  playlists: z.record(z.string(), z.array(z.string())),
})

// refine keys:
// z.string().regex(/^\d{4}-\d{2}\/\d{2}\/_\w+$/, {
//   message: "keys must blah blah"
// })

export type DayManifest = z.infer<typeof daySchema>
