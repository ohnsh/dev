#!/usr/bin/env bun

const dreg = /(?<!\d)(?<year>\d{4})[-_]?(?<month>\d{2})[-_]?(?<day>\d{2})([-_T ]?(?<hour>\d{2})[-_]?(?<minute>\d{2})[-_]?(?<second>[0-5][0-9])?)?/

const [,, $1] = Bun.argv

const match = dreg.exec($1)?.filter(i => (i !== undefined))
if (!match) { process.exit(1) }

const date = match.slice(1, 4).join('-'),
  time = match.slice(5).join(':'),
  datetime = date + (time && 'T' + time)

// NaN or milliseconds since epoch
new Date(datetime).getTime() || process.exit(1)

// Join with spaces for ingestion by shell script
// console.log(match.slice(1, 4).join(' ') + ' ' + match.slice(5).join(' '))

console.log(datetime)
