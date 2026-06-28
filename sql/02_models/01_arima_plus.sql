-- ARIMA_PLUS on reference zone 237 (univariate: timestamp + value only;
-- auto_arima picked (2,1,0) + daily/weekly seasonality).
-- Lost to the seasonal-naive baseline (MAE 37.66 vs 36.90), so per-zone
-- classical TS was dropped in favor of the boosted tree. Kept for the comparison.
-- holiday_region omitted: it needs daily+ series over a year, not 1 month hourly.
CREATE OR REPLACE MODEL `nyc-taxi-forecast.taxi_forecast.arima_zone237`
OPTIONS (
  model_type                = 'ARIMA_PLUS',
  time_series_timestamp_col = 'spine_hour',
  time_series_data_col      = 'pickup_count'
) AS
SELECT
  spine_hour,
  pickup_count
FROM `nyc-taxi-forecast.taxi_forecast.zone237_hourly_demand`;

-- Evaluate against the Jan 25-31 holdout. ML.EVALUATE without a data table
-- returns model metadata, NOT accuracy -- pass the holdout + horizon STRUCT:
--
--   SELECT * FROM ML.EVALUATE(
--     MODEL `nyc-taxi-forecast.taxi_forecast.arima_zone237_eval`,
--     (SELECT spine_hour, pickup_count
--      FROM `nyc-taxi-forecast.taxi_forecast.zone237_hourly_demand`
--      WHERE spine_hour >= '2022-01-25'),
--     STRUCT(168 AS horizon, TRUE AS perform_aggregation));
--
-- (arima_zone237_eval = same model trained on Jan 1-24 only.)
