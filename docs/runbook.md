# Runbook

## Before the first run

The Fabric workspace needs the Lakehouse, Warehouse, pipelines, Dataflows, notebooks, semantic model and report from this repository.

Also check the following:

- Fabric connections for the Lakehouse, Warehouse, Web sources and Key Vault are working.
- Azure Key Vault contains `openaq-api-key`.
- `taxi_zone_lookup.csv` is uploaded to `Files/bronze/reference/taxi_zone_lookup.csv`.
- All six Gold tables exist in `wh_nyc_taxi_analytics`.

## Loading Taxi data

`pl_nyc_taxi_ingestion` has a parameter called `p_taxi_month`.

- Leave it empty for the normal run. The pipeline uses the month from two months ago.
- Enter a month such as `2025-06` to load the file if it is missing from Bronze.
- If the Parquet file is already in Bronze, the copy step is skipped.

The Silver notebook always reads all Taxi Parquet files currently stored in Bronze and rebuilds the full Silver table. The standalone Taxi pipeline stops after Silver; it does not update `FactTaxiDaily`.

For a historical backfill:

1. Run the Taxi pipeline once for every missing month.
2. After all files are present, run `pl_master_orchestration`. It runs `refresh_gold_taxi` and `validate_gold` as part of the normal sequence.

Before starting the master pipeline, make sure its normal target month (two months before the run date) is already in Bronze or available from TLC.

## Loading OpenAQ

Run `pl_openaq_ingestion`. The expected order is:

1. `web_get_openaq_secret`
2. `run_openaq_dataflow`
3. `run_silver_openaq`
4. `refresh_gold_air_quality`
5. `validate_openaq_freshness`

The Gold step reads the complete available Silver history. The final validation checks that Silver and Gold are not empty and that Gold contains the latest Silver date.

## Running the whole project

Run `pl_master_orchestration`. It processes Taxi and OpenAQ, runs the World Bank and ECB Dataflows, refreshes the economic tables, loads Taxi zones, refreshes the dimensions and finishes with `validate_gold`.

A correct run ends with these activities succeeding:

- `refresh_gold_economic`
- `nb_reference_zones`
- `refresh_gold_dimensions`
- `validate_gold`

## Schedules

- OpenAQ: every day at 04:00 Central European time.
- Master pipeline: day 20 of every month at 06:00 Central European time.
- Standalone Taxi schedule: disabled.

The standalone Taxi schedule should not be enabled at the same time as the monthly master schedule unless the two runs are intentionally separated.

## SQL checks

```sql
SELECT
    MIN(trip_date) AS first_taxi_date,
    MAX(trip_date) AS last_taxi_date,
    COUNT(*) AS taxi_rows
FROM dbo.FactTaxiDaily;

SELECT
    MIN(measurement_date) AS first_air_date,
    MAX(measurement_date) AS last_air_date,
    COUNT(DISTINCT measurement_date) AS air_days,
    COUNT(*) AS air_rows
FROM dbo.FactAirQualityDaily;

SELECT MAX(fx_date) AS last_fx_date
FROM dbo.DimFX;
```

Check pollutant units separately:

```sql
SELECT
    pollutant,
    units,
    COUNT(*) AS total_records,
    MIN(measurement_date) AS first_date,
    MAX(measurement_date) AS last_date
FROM dbo.FactAirQualityDaily
GROUP BY pollutant, units
ORDER BY pollutant, units;
```

## Common problems

### Taxi file is not found

The requested TLC month may not be published yet. Try an earlier month or run with an explicit `p_taxi_month`.

### `silver_taxi_zones` is missing

Check the location of `taxi_zone_lookup.csv`, then run `nb_reference_zones` again.

### OpenAQ secret step fails

Check the Key Vault connection, secret name and permission to read the secret. Do not put the key directly into the Dataflow.

### OpenAQ freshness check fails

Check the latest date in `silver_openaq_daily` and the result of the OpenAQ Dataflow. Then compare it with the latest date in `FactAirQualityDaily`.

### ECB date looks old

ECB does not publish a rate on every weekend or holiday. Compare the latest Bronze, Silver and `DimFX` dates before treating this as an error.

## Final Power BI check

- All four pages open without errors.
- Taxi charts stop at the expected loaded month.
- Air-quality visuals use Average for `avg_pollution`. The current data uses PM2.5 in `µg/m³` and NO₂ in `ppm`.
- Both average revenue per trip cards have values.
- The USD/EUR chart uses the expected dates.

For the final submission, keep screenshots of the successful OpenAQ and master runs, the Warehouse date checks, the report pages and the schedules.
