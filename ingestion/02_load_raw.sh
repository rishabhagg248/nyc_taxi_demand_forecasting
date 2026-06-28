#!/usr/bin/env bash
# Load GCS Parquet into per-year raw BigQuery tables.
# Per-year splits dodge a cross-year column type conflict (passenger_count etc.),
# which the normalize step drops anyway. The 2026 wildcard self-adjusts.
set -euo pipefail

PROJECT="nyc-taxi-forecast"
DATASET="taxi_forecast"
BUCKET="gs://nyc-taxi-forecast-tlc"

for y in 2022 2023 2024 2025 2026; do
  echo "=> loading ${y}"
  bq load --source_format=PARQUET --autodetect --replace \
    "${PROJECT}:${DATASET}.tlc_yellow_raw_${y}" \
    "${BUCKET}/yellow_tripdata_${y}-*.parquet"
done

# ---------------------------------------------------------------------------
# Cleaner alternative: one external table declaring ONLY the two columns used.
# Columnar reads never touch the others, so cross-year type drift is irrelevant
# and the per-year raw tables become unnecessary.
#
#   bq query --use_legacy_sql=false '
#   CREATE OR REPLACE EXTERNAL TABLE `taxi_forecast.tlc_yellow_ext` (
#     tpep_pickup_datetime TIMESTAMP,
#     PULocationID         INT64
#   )
#   OPTIONS (
#     format = "PARQUET",
#     uris   = ["gs://nyc-taxi-forecast-tlc/yellow_tripdata_*.parquet"]
#   );'
# ---------------------------------------------------------------------------
