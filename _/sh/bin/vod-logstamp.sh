#!/usr/bin/env bash

year_mo=$(basename "$PWD")

if ! [[ $year_mo =~ ^[0-9]{4}-(0[1-9]|1[0-2])$ ]]; then
  echo "Please run from an archive root directory (YYYY-mm)" >&2
  exit 1
fi

for cam_dir; do
  cam=$(basename "$cam_dir")
  if ! [[ $cam =~ ^[[:alnum:]_-]+$ ]]; then
    echo "Invalid cam directory: $cam" >&2
    exit 1
  elif [[ $cam == _manifest* ]]; then
    echo "Skipping $cam" >&2
    continue
  fi

  day_dir=$(cd "$cam_dir/.." && pwd) || exit
  day=$(basename "$day_dir")

  if ! [[ $day =~ [0-3][0-9] ]]; then
    echo "Invalid day directory: $day" >&2
    exit 1
  fi

  mbase=vod-manifest_${year_mo}-${day}_${cam}
  legacy_mbase=manifest_${year_mo}_${day}_${cam}

  manifest=$day_dir/_manifest/${mbase}.txt
  legacy_manifests=("$day_dir/_manifest/${legacy_mbase}"*.txt)

  if [[ -e $manifest && $manifest -nt $cam_dir ]]; then
    echo "Skipping $cam (older than existing manifest)" >&2
    continue
  fi

  for legacy_manifest in "${legacy_manifests[@]}"; do
    if [[ -e $legacy_manifest && $legacy_manifest -nt $cam_dir ]]; then
      echo "Skipping $cam (older than existing legacy manifest)" >&2
      continue 2
    fi
  done

  vod timestamp create "$cam_dir" \
    --archive-root . \
    --manifest "$manifest"
done
