# NYC Taxi Demand dashboard (Streamlit, deployed on Cloud Run).
#   Tab 1: model predicted vs actual on the held-out window, per zone.
#   Tab 2: seasonal climatology -- typical demand by date/zone/hour. It's a
#          historical average, labeled as such, not a forward prediction.
# Auth via ADC: the Cloud Run service account in prod, gcloud login locally.
import streamlit as st
import pandas as pd
from google.cloud import bigquery

PROJECT = "nyc-taxi-forecast"
DATASET = "taxi_forecast"
FEATURES = f"`{PROJECT}.{DATASET}.all_zones_hourly_features`"
MODEL = f"`{PROJECT}.{DATASET}.boosted_all_zones`"
HOLDOUT_START = "2026-03-01"  # Mar-Apr 2026 was the honest test window

st.set_page_config(page_title="NYC Taxi Demand", layout="wide")
bq = bigquery.Client(project=PROJECT)


@st.cache_data(ttl=3600)
def run(sql: str) -> pd.DataFrame:
    return bq.query(sql).to_dataframe()


@st.cache_data(ttl=3600)
def zone_list() -> list:
    df = run(f"SELECT DISTINCT pickup_location_id AS Zone FROM {FEATURES} ORDER BY 1")
    return df["Zone"].tolist()


# --- Tab 1 data: predicted vs actual on the holdout, for one zone -----------
@st.cache_data(ttl=3600)
def forecast_for_zone(zone: str) -> pd.DataFrame:
    return run(f"""
        SELECT spine_hour,
               pickup_count                AS actual,
               predicted_pickup_count      AS predicted
        FROM ML.PREDICT(MODEL {MODEL},
          (SELECT * FROM {FEATURES}
           WHERE lag_168h IS NOT NULL
             AND spine_hour >= '{HOLDOUT_START}'
             AND pickup_location_id = '{zone}'))
        ORDER BY spine_hour
    """)


# --- Tab 2 data: seasonal climatology profile (built once, cached) ----------
@st.cache_data(ttl=86400)
def climatology() -> pd.DataFrame:
    return run(f"""
        SELECT pickup_location_id            AS Zone,
               EXTRACT(MONTH FROM spine_hour) AS month_num,
               FORMAT_DATE('%A', DATE(spine_hour)) AS weekday,
               EXTRACT(HOUR FROM spine_hour)  AS hour_of_day,
               AVG(pickup_count)              AS avg_pickups,
               APPROX_QUANTILES(pickup_count, 2)[OFFSET(1)] AS median_pickups,
               COUNT(*)                       AS n_obs
        FROM {FEATURES}
        GROUP BY Zone, month_num, weekday, hour_of_day
    """)


tab1, tab2 = st.tabs(["Model forecast", "Seasonal climatology"])

# ===========================================================================
# TAB 1 - model vs actual on the held-out window
# ===========================================================================
with tab1:
    st.subheader("Predicted vs actual demand (held-out Mar-Apr 2026)")
    zone1 = st.selectbox("Zone", zone_list(), key="z1")
    df = forecast_for_zone(zone1)

    if df.empty:
        st.info("No holdout rows for this zone.")
    else:
        wape = (df["actual"] - df["predicted"]).abs().sum() / max(df["actual"].sum(), 1)
        c1, c2 = st.columns(2)
        c1.metric("Zone WAPE", f"{wape:.1%}")
        c2.metric("Total actual pickups (holdout)", f"{int(df['actual'].sum()):,}")

        chart = df.set_index("spine_hour")[["actual", "predicted"]]
        st.line_chart(chart)
        st.caption("Hourly predicted vs actual across the held-out window.")

# ===========================================================================
# TAB 2 - seasonal climatology lookup (an honest average, not a prediction)
# ===========================================================================
with tab2:
    st.subheader("Typical demand by date, zone and hour")
    prof = climatology()

    zone2 = st.selectbox("Zone", zone_list(), key="z2")
    picked = st.date_input("Date")
    hour = st.slider("Hour of day", 0, 23, 17)

    mo = picked.month
    wd = picked.strftime("%A")
    row = prof[(prof["Zone"] == zone2) & (prof["month_num"] == mo)
               & (prof["weekday"] == wd) & (prof["hour_of_day"] == hour)]

    if row.empty:
        st.info("No matching historical hours for that combination.")
    else:
        r = row.iloc[0]
        st.metric(f"Typical pickups - {zone2}, {wd} {hour:02d}:00 in {picked.strftime('%B')}",
                  f"~{r['avg_pickups']:.0f}")
        st.caption(f"Median {r['median_pickups']:.0f} - based on {int(r['n_obs'])} "
                   f"matching hours in 2022-2026")

        day = (prof[(prof["Zone"] == zone2) & (prof["month_num"] == mo) & (prof["weekday"] == wd)]
               .sort_values("hour_of_day").set_index("hour_of_day")[["avg_pickups"]])
        st.caption(f"Typical {wd} in {picked.strftime('%B')}, by hour")
        st.bar_chart(day)
