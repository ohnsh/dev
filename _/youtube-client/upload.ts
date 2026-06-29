import { createReadStream } from 'node:fs'
// import readline from 'node:readline/promises'
import google from '@googleapis/youtube'
import auth from './auth'
import clientConfig from './client-config'

const oauthClient = await auth(await clientConfig)

const youtube = google.youtube({ version: 'v3', auth: oauthClient })
const vid =
  '/Volumes/Media/days/2026-06/25/_capture_2x2/2026-06-25_15-01-00.mp4'
const body = createReadStream(vid)

await youtube.videos.insert({
  part: ['snippet', 'status'],
  requestBody: {
    snippet: {
      title: 'Test vid: Device flow.',
      description: 'Uploaded via script.',
      tags: ['api', 'automation'],
    },
    status: {
      privacyStatus: 'public',
    },
  },
  media: {
    mimeType: 'video/mp4',
    body,
  },
})
