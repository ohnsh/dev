import type { youtube_v3 } from '@googleapis/youtube'

export default function (youtube: youtube_v3.Youtube) {
  return {
    getDefaultStream,
    goLive,
    getRecentBroadcasts,
    getReadyBroadcast,
    createBroadcast,
  }

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

    return defaultStream as typeof defaultStream & { id: string }
  }

  async function goLive() {
    const broadcastResp = await youtube.liveBroadcasts.list({
      part: ['id', 'snippet', 'contentDetails', 'status'],
      mine: true,
    })

    if (!broadcastResp.ok || !broadcastResp.data.items) {
      throw broadcastResp
    }

    const readyBroadcast = broadcastResp.data.items.find(
      (item) => item.status?.lifeCycleStatus === 'ready',
    )

    if (!readyBroadcast?.id) {
      throw new Error('No broadcasts in `ready` state.')
    }

    // need to transition from ready to live
    const txResp = await youtube.liveBroadcasts.transition({
      id: readyBroadcast.id,
      part: ['snippet', 'status'],
      broadcastStatus: 'live',
    })

    if (!txResp.ok) {
      throw txResp
    }

    return txResp.data
  }

  async function getRecentBroadcasts() {
    const broadcastResp = await youtube.liveBroadcasts.list({
      part: ['id', 'snippet', 'contentDetails', 'status'],
      mine: true,
    })

    if (!broadcastResp.ok || !broadcastResp.data.items) {
      throw broadcastResp
    }

    return broadcastResp.data.items
  }

  async function getReadyBroadcast() {
    const recentBroadcasts = await getRecentBroadcasts()
    const readyBroadcast = recentBroadcasts.find(
      (item) => item.status?.lifeCycleStatus === 'ready',
    )

    return readyBroadcast
  }

  async function createBroadcast(streamId: string) {
    const now = new Date()
    const title = `🔴 Live ${now.getMonth() + 1}/${now.getDate()}`

    const resp = await youtube.liveBroadcasts.insert({
      part: ['snippet', 'status', 'contentDetails'],
      requestBody: {
        snippet: {
          title,
          scheduledStartTime: new Date().toISOString(),
        },
        status: {
          privacyStatus: 'public',
          selfDeclaredMadeForKids: false,
        },
        contentDetails: {
          enableAutoStart: true,
          enableAutoStop: true,
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

    return resp.data
  }
}

// await youtube.liveStreams.insert({ part: [''] })
