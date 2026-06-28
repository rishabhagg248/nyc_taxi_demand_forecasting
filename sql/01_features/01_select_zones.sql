-- Historical: >=7,400 Jan-trips volume floor -> 52 zones (52 kept / 205 dropped).
-- The final model dropped this cutoff and modeled all ~263 zones; kept for reference.
-- (HAVING, not WHERE, because the filter is on an aggregate count.)
CREATE OR REPLACE TABLE `nyc-taxi-forecast.taxi_forecast.zones_52` AS
SELECT pickup_location_id,
       COUNT(*) AS jan_trips
FROM `nyc-taxi-forecast.taxi_forecast.tlc_yellow_all`
WHERE pickup_datetime >= '2022-01-01' AND pickup_datetime < '2022-02-01'
  AND pickup_location_id IS NOT NULL
GROUP BY pickup_location_id
HAVING jan_trips >= 7400          -- the volume floor; post-aggregation filter
ORDER BY jan_trips DESC;

-- Sanity check on how hard the floor cuts:
--   SELECT COUNTIF(jan_trips >= 7400) AS zones_kept,
--          COUNTIF(jan_trips <  7400) AS zones_dropped
--   FROM ( ... the GROUP BY above without the HAVING ... );
-- This returned 52 kept / 205 dropped.
