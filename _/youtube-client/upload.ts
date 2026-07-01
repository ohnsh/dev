import { createReadStream } from 'node:fs'
import { youtube_v3 } from '@googleapis/youtube'

export default function (youtube: youtube_v3.Youtube) {
  return {
    async uploadVideo(path: string) {
      const body = createReadStream(path)

      await youtube.videos.insert({
        part: ['snippet', 'status'],
        requestBody: {
          snippet: {
            title: 'Test vid: Device flow.',
            description: 'Uploaded via script.',
            tags: ['api', 'automation'],
          },
          status: {
            privacyStatus: 'public',
          },
        },
        media: {
          mimeType: 'video/mp4',
          body,
        },
      })
    },
  }
}
