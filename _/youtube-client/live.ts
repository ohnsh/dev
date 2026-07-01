import { youtube_v3 } from '@googleapis/youtube'

export default function (youtube: youtube_v3.Youtube) {
  return {
    async getDefaultStream() {
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
    },

    async getReadyBroadcast() {
      const broadcastResp = await youtube.liveBroadcasts.list({
        part: ['id', 'snippet', 'contentDetails', 'status'],
        mine: true,
      })

      if (!broadcastResp.ok || !broadcastResp.data.items) {
        throw broadcastResp
      }

      let [latestBroadcast] = broadcastResp.data.items

      if (
        !latestBroadcast ||
        latestBroadcast.status?.lifeCycleStatus !== 'ready'
      ) {
        return undefined
      }

      return latestBroadcast
    },

    async createNewBroadcast(streamId: string) {
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
  // need to transition from ready to live
  await youtube.liveBroadcasts.transition({
    part: ['snippet', 'status'],
    broadcastStatus: 'ready',  // 'live'
  })
  */

      return resp.data
    },
  }
}

// await youtube.liveStreams.insert({ part: [''] })
