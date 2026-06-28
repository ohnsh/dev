#!/usr/bin/env bun

import { parseArgs } from 'node:util'
import { $, argv } from 'bun'
import sharp from 'sharp'

// const metadata = await sharp(inputImagePath).metadata()

const { values, positionals } = parseArgs({
  args: argv,
  options: {
    radius: { type: 'string', short: 'r' },
    width: { type: 'string', short: 'w' },
    height: { type: 'string', short: 'h' },
  },
  strict: true,
  allowPositionals: true,
})

const { radius = '50', width = '600', height = '600' } = values

const svgString = `
<svg width="${width}" height="${height}">
  <rect width="${width}" height="${height}" rx="${radius}" fill="white" />
</svg>`

const [, , fname = 'out.png'] = positionals

await sharp(new TextEncoder().encode(svgString)).png().toFile(fname)

// await $`open ${fname}`
