// https://www.simple-ffmpegjs.com/
//
import SIMPLEFFMPEG from 'simple-ffmpegjs'

const project = new SIMPLEFFMPEG({ preset: 'youtube' })

await project.load([
  { type: 'video', url: './intro.mp4', duration: 5 },
  {
    type: 'video',
    url: './clip2.mp4',
    duration: 6,
    transition: { type: 'fade', duration: 0.5 },
  },
  {
    type: 'text',
    text: 'Summer Highlights',
    position: 0.5,
    end: 4,
    fontSize: 64,
    fontColor: '#FFFFFF',
    animation: { type: 'pop', in: 0.3 },
  },
  { type: 'music', url: './music.mp3', volume: 0.2, loop: true },
])

await project.export({ outputPath: './output.mp4' })
