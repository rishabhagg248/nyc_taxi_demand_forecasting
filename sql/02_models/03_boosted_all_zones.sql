-- Final model: one joint boosted tree across all ~263 zones, multi-year.
-- Zone id rides along as a categorical feature -> cross-zone pooling beats
-- per-zone specialists (MAE 29.46 on zone 237, under both the naive and 237-only).
-- SEQ = time-ordered split, never random. Holdout (Mar-Apr 2026) carved out by
-- hand so the naive baseline scores the identical rows.
-- SELECT * is safe here: spine_hour is auto-dropped, zone id is now a feature.
CREATE OR REPLACE MODEL `nyc-taxi-forecast.taxi_forecast.boosted_all_zones`
OPTIONS (
  model_type               = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols         = ['pickup_count'],
  data_split_method        = 'SEQ',         -- time-ordered, NOT random
  data_split_col           = 'spine_hour',  -- split key only; auto-dropped from features
  data_split_eval_fraction = 0.1
) AS
SELECT *
FROM `nyc-taxi-forecast.taxi_forecast.all_zones_hourly_features`
WHERE lag_168h IS NOT NULL        -- drop each zone's first week (lags not yet formed)
  AND spine_hour < '2026-03-01';  -- Mar-Apr 2026 reserved for the honest test
