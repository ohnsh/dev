import google from '@googleapis/youtube'
import auth from './auth'

const oauthClient = await auth()
const youtube = google.youtube({ version: 'v3', auth: oauthClient })

const streamsResp = await youtube.liveStreams.list({
  part: ['id', 'snippet', 'status', 'cdn'],
  mine: true,
})

if (!streamsResp.ok || !streamsResp.data.items) {
  throw streamsResp
}

for (const item of streamsResp.data.items) {
  console.log({
    id: item.id,
    snippet: item.snippet,
    status: item.status,
    cdn: item.cdn,
  })
}

const broadcastResp = await youtube.liveBroadcasts.list({
  part: ['id', 'snippet', 'contentDetails', 'status', 'statistics'],
  mine: true,
})

if (!broadcastResp.ok || !broadcastResp.data.items) {
  throw broadcastResp
}

for (const item of broadcastResp.data.items.slice(0, 2)) {
  console.log({
    id: item.id,
    snippet: item.snippet,
    status: item.status,
    contentDetails: item.contentDetails,
    statistics: item.statistics,
  })
}

// await youtube.liveStreams.insert({ part: [''] })
