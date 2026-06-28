-- Per-year raw tables -> one date-partitioned table (pickup time + zone only).
-- Dropping the other columns is also what makes the cross-year type drift moot.
-- STRING zone id = auto-categorical in BQML tree models; partition keeps scans cheap.
CREATE OR REPLACE TABLE `nyc-taxi-forecast.taxi_forecast.tlc_yellow_all`
PARTITION BY DATE(pickup_datetime) AS
SELECT tpep_pickup_datetime         AS pickup_datetime,
       CAST(PULocationID AS STRING) AS pickup_location_id
FROM `nyc-taxi-forecast.taxi_forecast.tlc_yellow_raw_2022`
UNION ALL SELECT tpep_pickup_datetime, CAST(PULocationID AS STRING) FROM `nyc-taxi-forecast.taxi_forecast.tlc_yellow_raw_2023`
UNION ALL SELECT tpep_pickup_datetime, CAST(PULocationID AS STRING) FROM `nyc-taxi-forecast.taxi_forecast.tlc_yellow_raw_2024`
UNION ALL SELECT tpep_pickup_datetime, CAST(PULocationID AS STRING) FROM `nyc-taxi-forecast.taxi_forecast.tlc_yellow_raw_2025`
UNION ALL SELECT tpep_pickup_datetime, CAST(PULocationID AS STRING) FROM `nyc-taxi-forecast.taxi_forecast.tlc_yellow_raw_2026`;

-- Verify: month counts across the span. Expect ~52 clean months (TLC's own
-- dirty rows can push it to ~54), Dec 2022 now ~3.4M instead of 57.
SELECT EXTRACT(YEAR  FROM pickup_datetime) AS yr,
       EXTRACT(MONTH FROM pickup_datetime) AS mo,
       COUNT(*)                            AS trips
FROM `nyc-taxi-forecast.taxi_forecast.tlc_yellow_all`
WHERE pickup_datetime >= '2022-01-01'
GROUP BY yr, mo
ORDER BY yr, mo;
