-- Feature table: one row per (zone, hour), leakage-safe. Both models train on this.
-- Invariants (each marked at its line below):
--   dense spine + gap-fill 0s | per-zone window partitions |
--   rolling frames end at 1 PRECEDING (no target leakage) | one continuous timeline.
-- Models all zones (no volume cutoff) -- the joint tree pools across them.
CREATE OR REPLACE TABLE `nyc-taxi-forecast.taxi_forecast.all_zones_hourly_features` AS
WITH
-- (1) actual hourly pickups per zone; the partition filter keeps the scan cheap
hourly_counts AS (
  SELECT
    pickup_location_id,
    TIMESTAMP_TRUNC(pickup_datetime, HOUR) AS spine_hour,
    COUNT(*)                               AS pickup_count
  FROM `nyc-taxi-forecast.taxi_forecast.tlc_yellow_all`
  WHERE pickup_datetime >= '2022-01-01' AND pickup_datetime < '2026-05-01'
    AND pickup_location_id IS NOT NULL
  GROUP BY 1, 2
),

-- (2) complete zone x hour grid: every zone that appears x every hour in span
zones AS ( SELECT DISTINCT pickup_location_id FROM hourly_counts ),
hours AS (
  SELECT h AS spine_hour
  FROM UNNEST(GENERATE_TIMESTAMP_ARRAY(
         TIMESTAMP '2022-01-01 00:00:00',
         TIMESTAMP '2026-04-30 23:00:00',
         INTERVAL 1 HOUR)) AS h
),
spine AS ( SELECT z.pickup_location_id, hr.spine_hour FROM zones z CROSS JOIN hours hr ),

-- (3) gap-filled demand: 0 is a TRUE zero here (no trips that hour)
demand AS (
  SELECT s.pickup_location_id, s.spine_hour, COALESCE(c.pickup_count, 0) AS pickup_count
  FROM spine s
  LEFT JOIN hourly_counts c
    ON s.pickup_location_id = c.pickup_location_id AND s.spine_hour = c.spine_hour
),

-- (4) holiday calendar: the day itself, and the pre/post window around it
holiday_days AS (
  SELECT DISTINCT primary_date AS holiday_date
  FROM `bigquery-public-data.ml_datasets.holidays_and_events_for_forecasting`
  WHERE region = 'US'
),
holiday_window_dates AS (
  SELECT DISTINCT day AS window_date
  FROM `bigquery-public-data.ml_datasets.holidays_and_events_for_forecasting` AS hol,
       UNNEST(GENERATE_DATE_ARRAY(
         DATE_SUB(hol.primary_date, INTERVAL hol.preholiday_days  DAY),
         DATE_ADD(hol.primary_date, INTERVAL hol.postholiday_days DAY))) AS day
  WHERE hol.region = 'US'
),
holiday_adjacent_dates AS (
  SELECT window_date AS adjacent_date
  FROM holiday_window_dates
  WHERE window_date NOT IN (SELECT holiday_date FROM holiday_days)  -- exclude the day itself
),

-- (5) features
features AS (
  SELECT
    d.pickup_location_id,
    d.spine_hour,
    d.pickup_count,                                              -- label

    -- lags (partitioned via WINDOW w below)
    LAG(d.pickup_count, 1)   OVER w AS lag_1h,
    LAG(d.pickup_count, 24)  OVER w AS lag_24h,
    LAG(d.pickup_count, 168) OVER w AS lag_168h,

    -- rolling means (leakage-safe; frame ends one hour before the row)
    AVG(d.pickup_count) OVER (PARTITION BY d.pickup_location_id ORDER BY d.spine_hour
      ROWS BETWEEN 24  PRECEDING AND 1 PRECEDING) AS roll_mean_24h,
    AVG(d.pickup_count) OVER (PARTITION BY d.pickup_location_id ORDER BY d.spine_hour
      ROWS BETWEEN 168 PRECEDING AND 1 PRECEDING) AS roll_mean_7d,

    -- calendar  (DAYOFWEEK: 1=Sun .. 7=Sat)
    EXTRACT(HOUR      FROM d.spine_hour) AS hour_of_day,
    EXTRACT(DAYOFWEEK FROM d.spine_hour) AS day_of_week,
    EXTRACT(MONTH     FROM d.spine_hour) AS month_of_year,

    -- holiday flags
    IF(hd.holiday_date  IS NULL, 0, 1) AS is_holiday,
    IF(ha.adjacent_date IS NULL, 0, 1) AS is_holiday_adjacent

  FROM demand AS d
  LEFT JOIN holiday_days           AS hd ON DATE(d.spine_hour) = hd.holiday_date
  LEFT JOIN holiday_adjacent_dates AS ha ON DATE(d.spine_hour) = ha.adjacent_date
  WINDOW w AS (PARTITION BY d.pickup_location_id ORDER BY d.spine_hour)
)

SELECT * FROM features;

-- ---------------------------------------------------------------------------
-- OPTIONAL: NOAA GSOD weather. GSOD is daily, so each day's reading broadcasts
-- to all 24 hours and every zone. Join a daily NYC station from
-- `bigquery-public-data.noaa_gsod` on DATE(spine_hour); select temp/prcp as
-- extra features. Left out of the headline build.
-- ---------------------------------------------------------------------------
