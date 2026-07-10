import type { youtube_v3 } from '@googleapis/youtube'

export default function (youtube: youtube_v3.Youtube) {
  return {
    getDefaultStream,
    goLive,
    getRecentBroadcasts,
    getReadyBroadcast,
    getPrunable,
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

  async function update() {
    youtube.liveBroadcasts.update({
      part: ['snippet'],
      requestBody: { snippet: { title: '' } },
    })
  }

  async function getPrunable() {
    const defaultTitle = getDefaultTitle()
    const recent = await getRecentBroadcasts()

    return recent.filter((item) => {
      if (!item.status || !item.contentDetails || !item.snippet) {
        return false
      }
      const { title } = item.snippet
      const { privacyStatus, lifeCycleStatus, recordingStatus } = item.status
      const { enableAutoStart, enableAutoStop } = item.contentDetails

      if (lifeCycleStatus !== 'ready' || recordingStatus !== 'notRecording') {
        return false
      }
      return (
        privacyStatus !== 'public' ||
        !enableAutoStart ||
        !enableAutoStop ||
        title !== defaultTitle
      )
    })
  }

  // This `transition` call seemingly isn't necessary.
  // (At least not when `enableAutoStart` is set on the broadcast.)
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

    // transition from ready (?) to live
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
      (item) =>
        item.status?.lifeCycleStatus === 'ready' &&
        item.contentDetails?.enableAutoStart,
    )

    return readyBroadcast
  }

  function getDefaultTitle() {
    const now = new Date()
    return `🔴 Live ${now.getMonth() + 1}/${now.getDate()}`
  }

  async function createBroadcast(streamId: string) {
    const title = getDefaultTitle()

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
