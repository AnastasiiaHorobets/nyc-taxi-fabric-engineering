# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "7f2bb0a7-1483-4d0c-a91b-0d4ad287ed43",
# META       "default_lakehouse_name": "lh_nyc_taxi",
# META       "default_lakehouse_workspace_id": "d517c4eb-a231-41fc-88a3-8e5812b39506",
# META       "known_lakehouses": [
# META         {
# META           "id": "7f2bb0a7-1483-4d0c-a91b-0d4ad287ed43"
# META         }
# META       ]
# META     }
# META   }
# META }

# MARKDOWN ********************

# # Silver Layer - OpenAQ Data Transformation

# CELL ********************

from pyspark.sql import functions as F

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df_locations = spark.table("dbo.bronze_openaq_locations")
df_sensors = spark.table("dbo.openaq_sensors")
df_measurements = spark.table("dbo.openaq_daily_measurements")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# OpenAQ — Schema Standardization

df_locations_clean = df_locations.withColumn(
    "id", F.col("id").cast("long")
)

df_sensors_clean = (
    df_sensors
    .withColumn("location_id", F.col("location_id").cast("long"))
    .withColumn("sensor_id", F.col("sensor_id").cast("long"))
)

df_measurements_clean = (
    df_measurements
    .withColumn("date_from", F.to_timestamp("date_from"))
    .withColumn("date_to", F.to_timestamp("date_to"))
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# OpenAQ - Data Quality Checks

# Check missing IDs
df_locations_clean.agg(
    F.count(F.when(F.col("id").isNull(), 1)).alias("null_location_ids")
).show()

df_sensors_clean.agg(
    F.count(F.when(F.col("location_id").isNull(), 1)).alias("null_location_ids"),
    F.count(F.when(F.col("sensor_id").isNull(), 1)).alias("null_sensor_ids")
).show()

# Check Measurement Data Quality
df_measurements_clean.agg(
    F.count("*").alias("total_measurements"),
    F.count(F.when(F.col("sensor_id").isNull(), 1)).alias("null_sensor_ids"),
    F.count(F.when(F.col("value").isNull(), 1)).alias("null_values"),
    F.count(F.when(F.col("value") < 0, 1)).alias("negative_values"),
    F.count(F.when(F.col("date_from").isNull(), 1)).alias("invalid_date_from"),
    F.count(F.when(F.col("date_to").isNull(), 1)).alias("invalid_date_to")
).show()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# OpenAQ - Data Cleaning

df_measurements_valid = (
    df_measurements_clean
    .filter(F.col("sensor_id").isNotNull())
    .filter(F.col("date_from").isNotNull())
    .filter(F.col("date_to").isNotNull())
    .filter(F.col("value").isNotNull())
    .filter(F.col("value") >= 0)
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Check Key Uniqueness

df_locations_clean.agg(
    F.count("*").alias("total_locations"),
    F.countDistinct("id").alias("unique_location_id")
).show()

df_sensors_clean.agg(
    F.count("*").alias("total_sensors"),
    F.countDistinct("sensor_id").alias("unique_sensor_ids")
).show()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Data Enrichment & Joins

df_openaq_joined = (
    df_measurements_valid.alias("m")
    .join(
        df_sensors_clean.alias("s"),
        F.col("m.sensor_id") == F.col("s.sensor_id"),
        "inner"
    )
    .join(
        df_locations_clean.alias("l"),
        F.col("s.location_id") == F.col("l.id"),
        "inner"
    )
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Select Columns

df_openaq_silver = df_openaq_joined.select(
    F.col("m.sensor_id").alias("sensor_id"),
    F.col("s.location_id").alias("location_id"),
    F.col("l.name").alias("location_name"),
    F.col("l.latitude").alias("latitude"),
    F.col("l.longitude").alias("longitude"),
    F.col("s.pollutant").alias("pollutant"),
    F.col("s.units").alias("units"),
    F.to_date(F.col("m.date_from")).alias("measurement_date"),
    F.col("m.value").alias("value")
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Validation

df_openaq_silver.agg(
    F.count("*").alias("total_measurements"),
    F.countDistinct(
        "sensor_id", "measurement_date"
    ).alias("unique_sensor_dates"),
    F.min("measurement_date").alias("first_date"),
    F.max("measurement_date").alias("last_date")
).show()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Write Silver Delta Table

(
    df_openaq_silver.write
    .format("delta")
    .mode("overwrite")
    .saveAsTable("dbo.silver_openaq_daily")
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ### OpenAQ Silver - Summary
# 
# - Standardized data types for IDs and timestamps.
# - Removed 12 invalid measurements (2 NULL and 10 negative values).
# - Joined measurements, sensors, and locations.
# - Checked key uniqueness and duplicate sensor-date combinations.
# - Validated 26,315 records for the period 2025-01-01 to 2026-11-16.
# - Saved the result as `dbo.silver_openaq_daily` (Delta Table).
