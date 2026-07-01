import google from '@googleapis/youtube'
import auth from './auth'
// import uploadOps from './upload'
import liveOps from './live'

const oauthClient = await auth()
const youtube = google.youtube({ version: 'v3', auth: oauthClient })

const { getDefaultStream, getReadyBroadcast, createNewBroadcast } =
  liveOps(youtube)
// const { uploadVideo } = uploadOps(youtube)

async function main() {
  const defaultStream = await getDefaultStream()
  let readyBroadcast = await getReadyBroadcast()

  if (readyBroadcast) {
    console.log('Found existing ready broadcast.')
  } else {
    console.log('Creating new broadcast.')
    readyBroadcast = await createNewBroadcast(defaultStream.id)
  }

  console.log(readyBroadcast)
}

await main()
