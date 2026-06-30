import google from '@googleapis/youtube'
import auth from './auth'

const oauthClient = await auth()
const youtube = google.youtube({ version: 'v3', auth: oauthClient })

const streams = await youtube.liveStreams.list({
  part: ['snippet', 'status'],
  mine: true,
})

// const json = await streams.json()
// const json = await streams.body?.json()
console.log(streams.data)
