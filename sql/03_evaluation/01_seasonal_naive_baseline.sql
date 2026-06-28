-- Seasonal-naive baseline (zone 237, Jan 25-31 holdout): predict each hour =
-- same hour last week (= lag_168h, already in the feature table). No model, just
-- score the lag. This is the 36.90 / 67.96 bar every model must beat.
SELECT
  AVG(ABS(pickup_count - lag_168h))            AS mae_naive,
  SQRT(AVG(POW(pickup_count - lag_168h, 2)))   AS rmse_naive
FROM `nyc-taxi-forecast.taxi_forecast.zone237_hourly_features`
WHERE lag_168h IS NOT NULL
  AND spine_hour >= '2022-01-25';
