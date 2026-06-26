import { createReadStream, readFile } from 'node:fs'
import { join } from 'node:path'
import readline from 'node:readline/promises'
import google from '@googleapis/youtube'
import Bun from 'bun'

// const auth = new google.auth.GoogleAuth({ apiKey: process.env.YT_API_KEY });
// const authClient = await auth.getClient()

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

const { client_id, client_secret, redirect_uris } = JSON.parse(
  await credContents,
).installed

const oauthClient = new google.auth.OAuth2({
  client_id,
  client_secret,
  redirect_uris,
})

const authUrl = oauthClient.generateAuthUrl({
  access_type: 'offline',
  scope: ['https://www.googleapis.com/auth/youtube.upload'],
})

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
})

const code = await rl.question(
  `Visit ${authUrl} to obtain authorization code. Enter the code here:`,
)
rl.close()

const { tokens } = await oauthClient.getToken(code)
oauthClient.setCredentials(tokens)

const youtube = google.youtube({ version: 'v3', auth: oauthClient })
const vid = '/Volumes/days/2026-06/25/_capture_2x2/2026-06-25_10-18-34.mp4'
const body = createReadStream(vid)

await youtube.videos.insert({
  part: ['snippet', 'status'],
  requestBody: {
    snippet: {
      title: 'Test vid.',
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
