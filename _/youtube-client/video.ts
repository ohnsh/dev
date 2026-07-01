import { createReadStream } from 'node:fs'
import type { youtube_v3 } from '@googleapis/youtube'

export default function (youtube: youtube_v3.Youtube) {
  return {
    upload,
  }

  async function upload(
    path: string,
    snippet: youtube_v3.Schema$VideoSnippet,
    isPublic = true,
  ) {
    const body = createReadStream(path)

    await youtube.videos.insert({
      part: ['snippet', 'status'],
      requestBody: {
        snippet,
        status: {
          privacyStatus: isPublic ? 'public' : 'private',
        },
      },
      media: {
        mimeType: 'video/mp4',
        body,
      },
    })
  }
}
