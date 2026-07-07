#!/usr/bin/env bun

import * as fs from 'node:fs/promises'
import { join } from 'node:path'
import { Temporal } from 'temporal-polyfill'
import type { DayManifest } from './schema'

const DAYS_PREFIX = '/Volumes/Media/days'
const OVERLAY_PREFIX = '/Volumes/Media/overlay'

const isVideoExt = (name: string) => /\.(mov|mp4)$/i.test(name)

async function getItemsFromDays(base: string, { filter = true } = {}) {
  const realBase = await fs.realpath(base)
  const listing = await fs.readdir(realBase, {
    recursive: true,
    withFileTypes: true,
  })

  const items = listing
    .filter((entry) => entry.isFile() && isVideoExt(entry.name))
    .map((entry) =>
      join(entry.parentPath.replace(DAYS_PREFIX, OVERLAY_PREFIX), entry.name),
    )

  if (!filter) {
    return items
  }

  const mask = await Promise.all(items.map((item) => fs.exists(item)))
  return items.filter((_, i) => mask[i])
}

async function getItemsFromOverlay(base: string) {
  const recurse = async (base: string): Promise<string[]> => {
    const listing = await fs.readdir(base, { withFileTypes: true })
    const intermediate = listing
      .filter((entry) => entry.isDirectory())
      .map(async (entry) => {
        const path = join(entry.parentPath, entry.name)
        return isVideoExt(path) ? path : await recurse(path)
      })

    return (await Promise.all(intermediate)).flat()
  }

  return recurse(await fs.realpath(base))
}

// Works with overlay paths. Really just an exercise.
async function getItemsFromGenerator(base: string) {
  const realBase = await fs.realpath(base)

  async function* recurse(base: string): AsyncIterable<string> {
    const listing = await fs.readdir(base, { withFileTypes: true })
    for (const entry of listing) {
      if (!entry.isDirectory()) {
        continue
      }

      const path = join(entry.parentPath, entry.name)
      if (isVideoExt(entry.name)) {
        // yield directories named like video files (and don't recurse into them).
        yield path
      } else {
        // recurse into other directories
        yield* recurse(path)
      }
    }
  }

  const result = []
  for await (const path of recurse(realBase)) {
    result.push(path)
  }

  return result
}

async function getAnnotation(item: string) {
  const metaPath = `${item}/meta.json`
  const meta = await Bun.file(item).json()

  // Time:
  //   "CreationDate": "2026:06:21 15:13:51-05:00"
  //   "CreateDate": "2026:06:21 15:13:51-05:00",
  // Video:
  // "ImageWidth": 1920,
  // "ImageHeight": 1080,
  // "Duration": "7.27 s",
  // "AvgBitrate": "8.77 Mbps",
  // "Rotation": 90
  // "Image": {
  //   "CompressorID": "hvc1",
  //   "SourceImageWidth": 1920,
  //   "SourceImageHeight": 1080,
  //   "XResolution": 72,
  //   "YResolution": 72,
  //   "CompressorName": "HEVC",
  //   "BitDepth": 24,
  //   "ImageSize": "1920x1080",
  //   "Megapixels": 2.1
  // },
  // "Camera": {
  //   "LensModel-eng-US": "iPhone 15 Pro back camera 6.765mm f/1.78",
  //   "FocalLengthIn35mmFormat-eng-US": 24,
  //   "Make": "Apple",
  //   "Model": "iPhone 15 Pro",
  //   "LensModel": "iPhone 15 Pro back camera 6.765mm f/1.78",
  //   "FocalLengthIn35mmFormat": 24,
  //   "LensID": "iPhone 15 Pro back camera 6.765mm f/1.78"
  // },
}

function collateItems(items: string[], { annotate = true } = {}) {
  const collated = items.reduce<Record<string, string[]>>((working, item) => {
    const segments = item.slice(OVERLAY_PREFIX.length + 1).split('/')
    const [yearMonth, day, category, ...rest] = segments

    const prefix = [yearMonth, day, category].join('/')
    working[prefix] ??= []
    working[prefix].push(rest.join('/'))
    return working
  }, {})

  Object.values(collated).forEach((list) => {
    list.sort()
  })
  return collated
}

function assertOneArg(
  argv: string[],
): asserts argv is [string, string, string] {
  if (argv.length !== 3) {
    throw new Error('Exactly one argument required.')
  }
}

async function parseArg(arg: string) {
  function matchPathDate(path: string) {
    const matches = path.match(
      /(^|\/)days\/(?<year>\d{4})-(?<month>\d{2})\/(?<day>\d{2})($|\/)/,
    )
    if (!matches) {
      throw new Error("Couldn't parse date from path.")
    }
    return matches.groups as { year: string; month: string; day: string }
  }

  let date: Temporal.PlainDate
  let path: string

  try {
    date = Temporal.PlainDate.from(arg)
    const [day, month] = [date.day, date.month].map((n) =>
      n.toString().padStart(2, '0'),
    )
    path = `${OVERLAY_PREFIX}/${date.year}-${month}/${day}`
  } catch {
    path = await fs.realpath(arg)
    const { year, month, day } = matchPathDate(path)
    date = Temporal.PlainDate.from(`${year}-${month}-${day}`)
  }

  return { date, path }
}

assertOneArg(process.argv)
const [, , arg] = process.argv
const { path } = await parseArg(arg)

const items = path.includes(DAYS_PREFIX)
  ? await getItemsFromDays(path)
  : await getItemsFromOverlay(path)

const playlists = collateItems(items, { annotate: true })
const manifest: DayManifest = { playlists }

console.write(JSON.stringify(manifest, undefined, 2))
