#!/usr/bin/env bash
# Stream TLC yellow-taxi Parquet from CloudFront into GCS.
# CloudFront is the source of record (the BQ public mirror was missing Dec 2022).
# Bucket is a literal (a lost shell var once broke a run); curl|gcloud cp avoids disk.
set -euo pipefail

BUCKET="gs://nyc-taxi-forecast-tlc"

# Full available span at time of build: Jan 2022 through Apr 2026 (52 months).
for y in 2022 2023 2024 2025 2026; do
  for m in 01 02 03 04 05 06 07 08 09 10 11 12; do
    ym="${y}-${m}"
    f="yellow_tripdata_${ym}.parquet"
    echo "=> ${f}"
    # skip months that don't exist yet (anything past 2026-04)
    curl -fsSL "https://d37ci6vzurychx.cloudfront.net/trip-data/${f}" \
      | gcloud storage cp - "${BUCKET}/${f}" || echo "   (skipped ${f})"
  done
done

# Expect 52 files, each ~45-55 MB. Anything a few KB is a partial -> re-fetch.
echo "--- bucket contents ---"
gcloud storage ls -l "${BUCKET}/"
