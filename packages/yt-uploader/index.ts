import { createReadStream, readFile } from 'node:fs'
import { join } from 'node:path'
import readline from 'node:readline/promises'
import google from '@googleapis/youtube'
import Bun from 'bun'
import { runDeviceFlow } from './device-flow'

// const auth = new google.auth.GoogleAuth({ apiKey: process.env.YT_API_KEY });
// const authClient = await auth.getClient()

// https://github.com/googleapis/google-api-nodejs-client
// https://console.cloud.google.com/apis/credentials?project=youtube-data-488423

const CREDENTIALS = join(import.meta.dir, '.client-secret.json')
const credContents = new Promise<string>((resolve, reject) => {
  readFile(CREDENTIALS, { encoding: 'utf8' }, (err, data) => {
    if (err !== null) {
      reject(err)
    } else {
      resolve(data)
    }
  })
})

const { client_id, client_secret } = JSON.parse(await credContents).installed

const { access_token, refresh_token } = await runDeviceFlow(
  client_id,
  client_secret,
)

const oauthClient = new google.auth.OAuth2({
  client_id,
  client_secret,
})

const scope = 'https://www.googleapis.com/auth/youtube.upload'

oauthClient.setCredentials({
  access_token,
  refresh_token,
  scope,
  token_type: 'Bearer',
})

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
