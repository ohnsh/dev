import google from '@googleapis/youtube'
import auth from './auth'
import clientConfig from './client-config'

const oauthClient = await auth(await clientConfig)
const youtube = google.youtube({ version: 'v3', auth: oauthClient })

const streams = await youtube.liveStreams.list({ part: ['snippet', 'status'] })

console.log(streams)
