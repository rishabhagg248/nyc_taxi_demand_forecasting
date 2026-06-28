# Evaluation Summary

All numbers below come from held-out data the models never trained on. The baseline everywhere is **seasonal-naive**: predict each zone-hour as whatever happened in the same zone, same hour, one week (168 hours) earlier.

## Primary metric: WAPE

WAPE = sum(|actual − predicted|) / sum(actual), aggregated over the holdout.

MAPE was rejected because it divides by actual demand, and many zone-hours have zero pickups (overnight, quiet zones), which makes MAPE undefined or explosive. WAPE weights by volume and stays well-defined. Aggregate MAE across zones was also rejected as a cross-zone comparison metric because it scales with zone volume — a busy zone's MAE dominates and hides what's happening in smaller zones.

## Citywide results (Mar–Apr 2026 holdout)

| Metric | Model | Seasonal-naive |
|---|---|---|
| Citywide WAPE | 19.76% | 23.40% |
| Relative improvement | ~15.5% | — |
| Zones beating baseline | 215 / 263 (81.7%) | — |
| Median per-zone WAPE | 0.685 | 0.786 |
| 90th-percentile per-zone WAPE | 2.41 | — |

The per-zone breakdown matters because the citywide number could in principle be carried by a few large zones. It isn't: most zones improve on their own.

## Model selection (reference zone 237, Jan 2022 holdout)

| Model | MAE | RMSE | Verdict |
|---|---|---|---|
| Seasonal-naive (lag 168h) | 36.90 | 67.96 | baseline |
| ARIMA_PLUS (per-zone) | 37.66 | 68.04 | lost to baseline |
| Boosted tree (single zone) | 31.95 | 42.06 | beat baseline |
| Boosted tree (joint, all zones) | 29.46 | — | best |

### Why the joint model won

The boosted tree trained across all zones at once beat the single-zone specialist on zone 237 itself. Cross-zone learning gives the model far more examples of the underlying shapes (morning rush, weekend dip, holiday flattening) than any one zone provides. The per-zone ARIMA, by contrast, never had enough signal per series and couldn't clear the naive baseline.

## Honest limitations

- Quiet zones produce high percentage error even when the absolute miss is tiny (one or two trips). That's what the 90th-percentile WAPE of 2.41 reflects — it's a property of sparse-series forecasting, not a bug.
- Metrics are reported against an in-sample naive denominator where MASE is used, which references the training-period naive error rather than the holdout naive error. Both are valid; they just answer slightly different questions.
