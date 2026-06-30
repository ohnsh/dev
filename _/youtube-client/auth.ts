import { join } from 'node:path'
// import { readFile } from 'node:fs/promises'
import google from '@googleapis/youtube'
import Bun from 'bun'
import { default as clientConfig, type ClientConfig } from './client-config'

// const auth = new google.auth.GoogleAuth({ apiKey: process.env.YT_API_KEY });

interface Credentials {
  access_token: string
  refresh_token: string
}

const CREDENTIALS_FILE = join(import.meta.dir, '.credentials.json')
const CB_PORT = 3000
const CB_PATH = '/callback'
const REDIRECT_URI = `http://localhost:${CB_PORT}${CB_PATH}`

const resolvedConfig = await clientConfig
const oauthClient = new google.auth.OAuth2({
  ...resolvedConfig,
  redirectUri: REDIRECT_URI,
})

export default async function () {
  let credentials: Credentials

  try {
    credentials = await Bun.file(CREDENTIALS_FILE).json()
  } catch {
    credentials = await runAuthFlow(resolvedConfig.scopes)
    await Bun.write(CREDENTIALS_FILE, JSON.stringify(credentials))
  }

  const { access_token, refresh_token } = credentials
  oauthClient.setCredentials({
    access_token,
    refresh_token,
    token_type: 'Bearer',
  })

  return oauthClient
}

async function runAuthFlow(scopes: string[]): Promise<Credentials> {
  const authUrl = oauthClient.generateAuthUrl({
    access_type: 'offline',
    scope: scopes.join(' '),
  })

  console.log(`Please visit the following URL to authorize:\n\n${authUrl}\n\n`)

  return new Promise((resolve, reject) => {
    const server = Bun.serve({
      port: CB_PORT,
      async fetch(req) {
        const url = new URL(req.url)

        if (url.pathname !== CB_PATH) {
          return new Response('Not found', { status: 404 })
        }

        const code = url.searchParams.get('code')
        const error = url.searchParams.get('error')

        if (error) {
          return new Response(`OAuth error: ${error}`, { status: 400 })
        }

        if (!code) {
          return new Response('OAuth callback missing code parameter', {
            status: 400,
          })
        }

        try {
          const tokenResponse = await oauthClient.getToken(code)
          resolve(tokenResponse.tokens as Credentials)
          return new Response('Authorization succeeded')
        } catch (e) {
          reject(e)
          return new Response(`Token exchange error: ${e}`, { status: 500 })
        } finally {
          server.stop()
        }
      },
    })
  })
}
