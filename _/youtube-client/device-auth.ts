import { join } from 'node:path'
// import { readFile } from 'node:fs/promises'
import google from '@googleapis/youtube'
import Bun from 'bun'
import type { ClientConfig } from './client-config'

// const auth = new google.auth.GoogleAuth({ apiKey: process.env.YT_API_KEY });
// const authClient = await auth.getClient()

interface Credentials {
  access_token: string
  refresh_token: string
}

const CREDENTIALS_FILE = join(import.meta.dir, '.credentials.json')

async function getCredentials(clientConfig: ClientConfig) {
  try {
    const credentials = await Bun.file(CREDENTIALS_FILE).json()
    return credentials
    // const json = await readFile(CREDENTIALS_FILE, { encoding: 'utf8' })
    // return JSON.parse(json)
  } catch {
    const credentials = await runDeviceFlow(clientConfig)
    await Bun.write(CREDENTIALS_FILE, JSON.stringify(credentials))
    return credentials
  }
}

export default async function (clientConfig: ClientConfig) {
  const { access_token, refresh_token } = await getCredentials(clientConfig)

  const oauthClient = new google.auth.OAuth2(clientConfig)

  oauthClient.setCredentials({
    access_token,
    refresh_token,
    scope: clientConfig.scopes.join(' '),
    token_type: 'Bearer',
  })

  return oauthClient
}

async function runDeviceFlow({
  client_id,
  client_secret,
  scopes,
}: ClientConfig): Promise<Credentials> {
  // STEP 1 & 2: Request device and user codes from Google
  const response = await fetch('https://oauth2.googleapis.com/device/code', {
    method: 'POST',
    body: new URLSearchParams({
      client_id,
      scope: scopes[1]!,
    }),
  })

  console.log(response)
  const json = await response.json()
  const { device_code, user_code, verification_url, interval, expires_in } =
    json

  // STEP 3: Display the code to the user
  console.log(
    `\n1. Go to this URL in your browser: \x1b[36m${verification_url}\x1b[0m`,
  )
  console.log(`2. Enter this code: \x1b[1;33m${user_code}\x1b[0m\n`)
  console.log('Waiting for authorization...')

  // STEP 4 & 5: Poll Google's token endpoint
  const pollIntervalMs = (interval || 5) * 1000

  return new Promise((resolve, reject) => {
    const pollTimer = setInterval(async () => {
      const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        body: new URLSearchParams({
          client_id,
          device_code,
          client_secret,
          grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
        }),
      })

      const tokenData = (await tokenResponse.json()) as
        | Credentials
        | { error: string }

      if ('error' in tokenData) {
        if (tokenData.error === 'authorization_pending') {
          // User hasn't typed the code in yet, keep waiting
          return
        } else if (tokenData.error === 'slow_down') {
          // Back off if requested by Google
          return
        } else {
          console.error(`\nAuthentication failed: ${tokenData.error}`)
          clearInterval(pollTimer)
          reject(tokenData)
          return
        }
      }

      console.log('Authorization succeeded.')
      clearInterval(pollTimer)
      resolve(tokenData)
    }, pollIntervalMs)
  })
}
