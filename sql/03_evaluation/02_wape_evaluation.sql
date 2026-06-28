-- Headline eval: model vs seasonal-naive on held-out Mar-Apr 2026.
-- WAPE = SUM(|err|)/SUM(actual), not MAPE: zero-demand hours (quiet zones at 4am)
-- make MAPE blow up; WAPE divides by the total, so zeros are harmless.
-- Baseline = lag_168h again, scored on the identical rows. Lower wins.
-- Result: citywide 19.76% vs 23.40%; 215/263 zones (81.7%) beat baseline;
-- median 0.685 vs 0.786; p90 2.41 (quiet zones, the honest limitation).

-- (a) per-zone: model vs naive, ordered by volume
SELECT
  pickup_location_id,
  SUM(ABS(pickup_count - predicted_pickup_count)) / NULLIF(SUM(pickup_count), 0) AS wape_model,
  SUM(ABS(pickup_count - lag_168h))               / NULLIF(SUM(pickup_count), 0) AS wape_naive,
  SUM(pickup_count) AS holdout_trips
FROM ML.PREDICT(
  MODEL `nyc-taxi-forecast.taxi_forecast.boosted_all_zones`,
  (SELECT * FROM `nyc-taxi-forecast.taxi_forecast.all_zones_hourly_features`
   WHERE lag_168h IS NOT NULL AND spine_hour >= '2026-03-01'))
GROUP BY pickup_location_id
ORDER BY holdout_trips DESC;

-- (b) one volume-weighted number for the whole city
SELECT
  SUM(ABS(pickup_count - predicted_pickup_count)) / SUM(pickup_count) AS wape_model_overall,
  SUM(ABS(pickup_count - lag_168h))               / SUM(pickup_count) AS wape_naive_overall
FROM ML.PREDICT(
  MODEL `nyc-taxi-forecast.taxi_forecast.boosted_all_zones`,
  (SELECT * FROM `nyc-taxi-forecast.taxi_forecast.all_zones_hourly_features`
   WHERE lag_168h IS NOT NULL AND spine_hour >= '2026-03-01'));

-- (c) share of zones that beat the baseline (the 81.7% number)
--   SELECT
--     COUNTIF(wape_model < wape_naive) AS zones_beat,
--     COUNT(*)                         AS zones_total,
--     APPROX_QUANTILES(wape_model, 100)[OFFSET(50)] AS median_wape,
--     APPROX_QUANTILES(wape_model, 100)[OFFSET(90)] AS p90_wape
--   FROM ( <the per-zone query (a) above> );
