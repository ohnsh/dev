const streamItem = {
  id: 'FpptpegJ_Ys54PGYwTYPPg1782715589941298',
  snippet: {
    publishedAt: '2026-06-29T06:46:30Z',
    channelId: 'UCFpptpegJ_Ys54PGYwTYPPg',
    title: 'Default',
    description: '',
    isDefaultStream: false,
  },
  status: {
    streamStatus: 'active', // 'inactive'
    healthStatus: {
      status: 'good', // 'noData'
    },
  },
  cdn: {
    ingestionType: 'rtmp',
    ingestionInfo: {
      streamName: '1cp9-g8sb-qpgf-azpt-9wf3',
      ingestionAddress: 'rtmp://a.rtmp.youtube.com/live2',
      backupIngestionAddress: 'rtmp://b.rtmp.youtube.com/live2?backup=1',
      rtmpsIngestionAddress: 'rtmps://a.rtmps.youtube.com/live2',
      rtmpsBackupIngestionAddress: 'rtmps://b.rtmps.youtube.com/live2?backup=1',
    },
    resolution: 'variable',
    frameRate: 'variable',
  },
}

const broadcastItem = {
  id: '94IvbWa_6iI',
  snippet: {
    publishedAt: '2026-06-30T20:51:56Z',
    channelId: 'UCFpptpegJ_Ys54PGYwTYPPg',
    title: '🔴 Live 6/30',
    description: '',
    thumbnails: {
      /*
      default: [Object ...],
      medium: [Object ...],
      high: [Object ...],
      standard: [Object ...],
      maxres: [Object ...],
    */
    },
    actualStartTime: '2026-06-30T20:53:26Z',
    actualEndTime: '2026-06-30T21:24:27Z',
    isDefaultBroadcast: false,
    liveChatId: 'KicKGFVDRnBwdHBlZ0pfWXM1NFBHWXdUWVBQZxILOTRJdmJXYV82aUk',
  },
  status: {
    lifeCycleStatus: 'complete', // 'live', 'ready' // 'created' important!
    privacyStatus: 'public',
    recordingStatus: 'recorded', // 'recording', 'notRecording'
    madeForKids: false,
    selfDeclaredMadeForKids: false,
  },
  contentDetails: {
    boundStreamId: 'FpptpegJ_Ys54PGYwTYPPg1782715589941298',
    boundStreamLastUpdateTimeMs: '2026-06-30T21:42:12Z',
    monitorStream: {
      enableMonitorStream: true,
      broadcastStreamDelayMs: 0,
      embedHtml:
        '<iframe width="425" height="344" src="https://www.youtube.com/embed/94IvbWa_6iI?autoplay=1&livemonitor=1" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>',
    },
    enableEmbed: true,
    enableDvr: true,
    enableContentEncryption: false,
    recordFromStart: true,
    enableClosedCaptions: false,
    closedCaptionsType: 'closedCaptionsDisabled',
    enableLowLatency: false,
    latencyPreference: 'normal',
    projection: 'rectangular',
    enableAutoStart: true,
    enableAutoStop: true,
  },
  statistics: {
    concurrentViewers: '0',
  },
}
