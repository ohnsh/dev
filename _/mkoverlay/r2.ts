import {
  HeadObjectCommand,
  ListObjectsV2Command,
  S3Client,
} from '@aws-sdk/client-s3'

export const r2 = new S3Client({
  endpoint: `https://${process.env.CF_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  region: 'auto',
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID!,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
  },
})

interface ListOpts {
  bucket?: string
  prefix?: string
  recurse?: boolean
  pageSize?: number
  startAfter?: string
}

export async function* listVids({
  bucket: Bucket = 'days',
  prefix: Prefix = '',
  recurse = true, // if false, important for prefix to either be empty or end in '/'
  pageSize: MaxKeys = 100, // default 1,000
  startAfter: StartAfter,
}: ListOpts = {}) {
  let token: string | undefined

  do {
    const resp = await r2.send(
      new ListObjectsV2Command({
        Bucket,
        Prefix,
        MaxKeys,
        Delimiter: recurse ? undefined : '/',
        StartAfter,
        ContinuationToken: token,
      }),
    )

    token = resp.IsTruncated ? resp.NextContinuationToken : undefined
    yield resp
  } while (token)
}

async function getContentType({ bucket: Bucket = 'days', key: Key = '' }) {
  const resp = await r2.send(
    new HeadObjectCommand({
      Bucket,
      Key,
    }),
  )
  return resp.ContentType
}
