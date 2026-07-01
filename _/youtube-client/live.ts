import google from '@googleapis/youtube'
import auth from './auth'

const oauthClient = await auth()
const youtube = google.youtube({ version: 'v3', auth: oauthClient })

async function getDefaultStream() {
  const streamsResp = await youtube.liveStreams.list({
    part: ['id', 'snippet', 'status', 'cdn'],
    mine: true,
  })

  if (!streamsResp.ok || !streamsResp.data.items) {
    throw streamsResp
  }

  const defaultStream = streamsResp.data.items.find(
    (item) => item.snippet?.title === 'Default',
  )

  if (!defaultStream?.id) {
    throw new Error('Default stream not found.')
  }

  if (defaultStream.status?.streamStatus === 'active') {
    throw new Error('Default stream key is already in use.')
  }

  return defaultStream as typeof defaultStream & { id: string }
}

async function getReadyBroadcast() {
  const broadcastResp = await youtube.liveBroadcasts.list({
    part: ['id', 'snippet', 'contentDetails', 'status'],
    mine: true,
  })

  if (!broadcastResp.ok || !broadcastResp.data.items) {
    throw broadcastResp
  }

  let [latestBroadcast] = broadcastResp.data.items

  if (!latestBroadcast || latestBroadcast.status?.lifeCycleStatus !== 'ready') {
    return undefined
  }

  return latestBroadcast
}

async function createNewBroadcast(streamId: string) {
  // need to create a new broadcast
  const resp = await youtube.liveBroadcasts.insert({
    part: ['snippet', 'status'],
    requestBody: {
      snippet: {
        title: '🔴 Live 6/30',
        scheduledStartTime: new Date().toISOString(),
      },
      status: {
        privacyStatus: 'public',
        selfDeclaredMadeForKids: false,
      },
    },
  })

  if (!resp.ok || !resp.data.id) {
    throw resp
  }

  const bindResp = await youtube.liveBroadcasts.bind({
    part: ['snippet', 'status'],
    id: resp.data.id,
    streamId,
  })

  if (!bindResp.ok) {
    throw bindResp
  }

  /*
  await youtube.liveBroadcasts.transition({
    part: ['snippet', 'status'],
    broadcastStatus: 'ready',  // 'live'
  })
  */

  return resp.data
}

async function main() {
  const defaultStream = await getDefaultStream()
  let readyBroadcast = await getReadyBroadcast()

  if (readyBroadcast) {
    console.log('Found existing ready broadcast.')
  } else {
    console.log('Creating new broadcast.')
    readyBroadcast = await createNewBroadcast(defaultStream.id)
  }

  console.log(readyBroadcast)
}

await main()

// await youtube.liveStreams.insert({ part: [''] })
