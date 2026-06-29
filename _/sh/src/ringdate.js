#!/usr/bin/env deno

const arg = Deno.args[0],
  inDate = arg.slice(0, 10),
  inHours = arg.slice(10, 12),
  d = new Date(inDate),
  z = d.getTimezoneOffset() * 60 * 1000

d.setHours(inHours, 0, 0)

if (d < new Date('2025-02') || d > new Date('2025-06')) {
  Deno.exit(1)
}

console.log(
  new Date(d - z).toISOString()
    .replace(/[-:]/g, '')
    .replace('T', '_')
    .replace(/\..+/, '')
  )
