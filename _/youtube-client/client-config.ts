import { readFile } from 'node:fs'
import { join } from 'node:path'

export interface ClientConfig {
  client_id: string
  client_secret: string
}

// https://github.com/googleapis/google-api-nodejs-client
// https://console.cloud.google.com/apis/credentials?project=youtube-data-488423

const CONFIG_FILE = join(import.meta.dir, '.client-secret.json')
const contents = new Promise<string>((resolve, reject) => {
  readFile(CONFIG_FILE, { encoding: 'utf8' }, (err, data) => {
    if (err !== null) {
      reject(err)
    } else {
      resolve(data)
    }
  })
})

export default contents.then(
  (text) => JSON.parse(text).installed as ClientConfig,
)
