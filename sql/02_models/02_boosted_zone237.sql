-- Single-zone boosted tree (237): proof a feature-based tree beats both ARIMA
-- and the naive baseline before scaling up. MAE 31.95 / RMSE 42.06 vs 36.90/67.96.
-- Explicit feature list (not SELECT *) excludes the raw timestamp and the
-- constant zone id. WHERE does the train/test split by hand to keep eval honest.
CREATE OR REPLACE MODEL `nyc-taxi-forecast.taxi_forecast.boosted_zone237`
OPTIONS (
  model_type            = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols      = ['pickup_count'],
  enable_global_explain = TRUE
) AS
SELECT
  pickup_count,
  lag_1h, lag_24h, lag_168h,
  roll_mean_24h, roll_mean_7d,
  hour_of_day, day_of_week, month_of_year,
  is_holiday, is_holiday_adjacent
FROM `nyc-taxi-forecast.taxi_forecast.zone237_hourly_features`
WHERE lag_168h IS NOT NULL
  AND spine_hour < '2022-01-25';

-- Feature importance readout:
--   SELECT * FROM ML.GLOBAL_EXPLAIN(
--     MODEL `nyc-taxi-forecast.taxi_forecast.boosted_zone237`);
--
-- BQML regressor eval returns MSE, so SQRT it for RMSE:
--   SELECT mean_absolute_error AS mae,
--          SQRT(mean_squared_error) AS rmse
--   FROM ML.EVALUATE(
--     MODEL `nyc-taxi-forecast.taxi_forecast.boosted_zone237`,
--     (SELECT * FROM `nyc-taxi-forecast.taxi_forecast.zone237_hourly_features`
--      WHERE lag_168h IS NOT NULL AND spine_hour >= '2022-01-25'));
