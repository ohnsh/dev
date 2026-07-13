#!/usr/bin/env bun

import { parseArgs } from 'node:util'
import google, { type youtube_v3 } from '@googleapis/youtube'
import auth from './auth'
import liveOps from './live'
import videoOps from './video'

const oauthClient = await auth()
const youtube = google.youtube({ version: 'v3', auth: oauthClient })
const [, , ...args] = Bun.argv

const { values, positionals } = parseArgs({
  args,
  options: {
    title: {
      type: 'string',
    },
    description: {
      type: 'string',
    },
  },
  strict: true,
  allowPositionals: true,
})

const {
  getDefaultStream,
  getReadyBroadcast,
  getRecentBroadcasts,
  getPrunable,
  createBroadcast,
  goLive,
} = liveOps(youtube)

const video = videoOps(youtube)

async function prepareReadyBroadcast({ prune = false } = {}) {
  if (prune) {
    const numPruned = await pruneBroadcasts()
    console.log(`Pruned ${numPruned} broadcasts.`)
  }

  let readyBroadcast = await getReadyBroadcast()
  if (readyBroadcast) {
    console.log('Existing ready broadcast:')
  } else {
    const defaultStream = await getDefaultStream()
    readyBroadcast = await createBroadcast(defaultStream.id, values)
    console.log('Created new broadcast:')
  }
  console.log(distillBroadcast(readyBroadcast))
}

async function pruneBroadcasts() {
  const prunable = await getPrunable()
  const responses = await Promise.all(
    prunable.map((item) => youtube.liveBroadcasts.delete({ id: item.id! })),
  )
  return responses.reduce((prev, cur) => prev + (cur.ok ? 1 : 0), 0)
}

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
  const [type, op] = positionals

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
        case 'prepare': {
          prepareReadyBroadcast({ prune: true })
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
        case 'prunable': {
          const prunable = await getPrunable()
          console.log(prunable.map(distillBroadcast))
          break
        }
        case 'prune': {
          const numPruned = await pruneBroadcasts()
          console.log(`Pruned ${numPruned} broadcasts.`)
          break
        }
        case 'new': {
          const defaultStream = await getDefaultStream()
          const newBroadcast = await createBroadcast(defaultStream.id, values)
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
      prepareReadyBroadcast({ prune: true })
      break
    }
    default: {
      console.error('First argument must be "video" or "broadcast".')
      process.exit(1)
    }
  }
}

await main()
