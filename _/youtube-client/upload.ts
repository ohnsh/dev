import { createReadStream } from 'node:fs'
// import readline from 'node:readline/promises'
import google from '@googleapis/youtube'
import auth from './auth'
import clientConfig from './client-config'

const SCOPE = 'https://www.googleapis.com/auth/youtube.upload'
const oauthClient = await auth(await clientConfig, SCOPE)

const youtube = google.youtube({ version: 'v3', auth: oauthClient })
const vid = '/Volumes/days/2026-06/25/_capture_2x2/2026-06-25_10-18-34.mp4'
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
