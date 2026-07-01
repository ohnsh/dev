#!/usr/bin/env bun

import google, { type youtube_v3 } from '@googleapis/youtube'
import auth from './auth'
import liveOps from './live'
import videoOps from './video'

const oauthClient = await auth()
const youtube = google.youtube({ version: 'v3', auth: oauthClient })
const [, , ...args] = Bun.argv

const {
  getDefaultStream,
  getReadyBroadcast,
  getRecentBroadcasts,
  createBroadcast,
  goLive,
} = liveOps(youtube)

const video = videoOps(youtube)

function distillBroadcast(apiBroadcast: youtube_v3.Schema$LiveBroadcast) {
  const { id, status, snippet, contentDetails } = apiBroadcast

  if (!id || !status || !snippet || !contentDetails) {
    throw new Error('Unexpected/invalid broadcast object.')
  }

  const { lifeCycleStatus, recordingStatus, privacyStatus } = status
  const { title, description, scheduledStartTime, actualStartTime } = snippet
  const { boundStreamId, enableAutoStart, enableAutoStop } = contentDetails

  return {
    id,
    status: {
      lifeCycleStatus,
      recordingStatus,
      privacyStatus,
    },
    title,
    description,
    scheduledStartTime,
    actualStartTime,
    boundStreamId,
    enableAutoStart,
    enableAutoStop,
  }
}

function distillStream(apiStream: youtube_v3.Schema$LiveStream) {
  const { id, status, snippet } = apiStream

  if (!id || !status || !snippet) {
    throw new Error('Unexpected/invalid stream object.')
  }

  const { title } = snippet
  return {
    id,
    title,
    status,
  }
}

async function main() {
  const type = args.shift()
  const op = args.shift()

  switch (type) {
    case 'video':
      switch (op) {
        case 'upload': {
          const [path, json] = args
          if (!path || !json) {
            throw new Error(
              'Must supply path to file and json for snippet ({ "title": "Title here" })',
            )
          }

          const snippet = JSON.parse(json)
          const exists = await Bun.file(path).exists()
          if (!exists || !snippet.title) {
            throw new Error('Lazy error.')
          }

          video.upload(path, snippet)
          break
        }
        default: {
          throw new Error(`Operation video ${op} not implemented.`)
        }
      }
      break
    case 'broadcast':
      switch (op) {
        case 'ensure': {
          let readyBroadcast = await getReadyBroadcast()
          if (readyBroadcast) {
            console.log('Existing ready broadcast:')
          } else {
            const defaultStream = await getDefaultStream()
            readyBroadcast = await createBroadcast(defaultStream.id)
            console.log('Created new broadcast:')
          }
          console.log(distillBroadcast(readyBroadcast))
          break
        }
        case 'golive': {
          const txData = await goLive()
          console.log(txData)
          break
        }
        case 'ready': {
          const readyBroadcast = await getReadyBroadcast()
          console.log(readyBroadcast)
          break
        }
        case 'new': {
          const defaultStream = await getDefaultStream()
          const newBroadcast = await createBroadcast(defaultStream.id)
          console.log(distillBroadcast(newBroadcast))
          break
        }
        default: {
          const broadcasts = await getRecentBroadcasts()
          const shorten = op !== '--long'
          console.log(shorten ? broadcasts.map(distillBroadcast) : broadcasts)
          break
        }
      }
      break
    case 'stream':
      switch (op) {
        default: {
          const defaultStream = await getDefaultStream()
          console.log(distillStream(defaultStream))
          break
        }
      }
      break
    case undefined: {
      const defaultStream = await getDefaultStream()
      let readyBroadcast = await getReadyBroadcast()

      if (readyBroadcast) {
        console.log('Found existing ready broadcast.')
      } else {
        console.log('Creating new broadcast.')
        readyBroadcast = await createBroadcast(defaultStream.id)
      }

      console.log(readyBroadcast)
      break
    }
    default: {
      console.error('First argument must be "video" or "broadcast".')
      process.exit(1)
    }
  }
}

await main()
