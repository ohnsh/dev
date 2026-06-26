export async function runDeviceFlow(client_id: string, client_secret: string) {
  const SCOPES = 'https://www.googleapis.com/auth/youtube.upload'

  // STEP 1 & 2: Request device and user codes from Google
  const response = await fetch('https://oauth2.googleapis.com/device/code', {
    method: 'POST',
    body: new URLSearchParams({
      client_id,
      scope: SCOPES,
    }),
  })

  const json = await response.json()
  console.log(json)
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

      const tokenData = await tokenResponse.json()

      if (tokenData.error) {
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
        }
      }

      // Success! We received the tokens
      clearInterval(pollTimer)
      resolve(tokenData)
    }, pollIntervalMs)
  })
}
