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

# # Silver Layer — Data Transformation

# CELL ********************

from pyspark.sql import functions as F
from pyspark.sql.window import Window
from pyspark.sql.types import DecimalType

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

bronze_path = "Files/bronze/yellow_taxi"

df_taxi = spark.read.parquet(bronze_path)

print("NYC Txi Bronze loaded successfuly")
print(f"Total columns: {len(df_taxi.columns)}")

df_taxi.printSchema()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df_taxi.select(
    "tpep_pickup_datetime",
    "tpep_dropoff_datetime",
    "trip_distance",
    "fare_amount",
    "tolls_amount",
).show(5, truncate=False)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

quality_check = df_taxi.agg(
    F.count("*").alias("total_trips"),

    F.sum(
        F.when(
            F.col("trip_distance") <= 0, 1
        ).otherwise(0)
    ).alias("invalid_distance"),

    F.sum(
        F.when(
            F.col("fare_amount") <= 0, 1
        ).otherwise(0)
    ).alias("invalid_fare"),

    F.sum(
        F.when(
            F.col("tpep_pickup_datetime").isNull(), 1
        ).otherwise(0)
    ).alias("null_pickup"),

    F.sum(
        F.when(
            F.col("tpep_dropoff_datetime").isNull(), 1
        ).otherwise(0)
    ).alias("null_dropoff"),

    F.sum(
        F.when(
            F.col("tpep_dropoff_datetime") <=
            F.col("tpep_pickup_datetime"), 1
        ).otherwise(0)
    ).alias("invalid_duration")
)

quality_check.show(truncate=False)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************


detailed_quality = df_taxi.agg(
    F.sum(F.when(F.col("trip_distance") == 0, 1).otherwise(0)).alias("zero_distance"),
    F.sum(F.when(F.col("trip_distance") < 0, 1).otherwise(0)).alias("negative_distance"),

    F.sum(F.when(F.col("fare_amount") == 0, 1).otherwise(0)).alias("zero_fare"),
    F.sum(F.when(F.col("fare_amount") < 0, 1).otherwise(0)).alias("negative_fare"),

    F.sum(F.when(
        F.col("tpep_dropoff_datetime") == F.col("tpep_pickup_datetime"), 1
    ).otherwise(0)).alias("zero_duration"),

    F.sum(F.when(
        F.col("tpep_dropoff_datetime") < F.col("tpep_pickup_datetime"), 1
    ).otherwise(0)).alias("negative_duration")
)

detailed_quality.show(truncate=False)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Inspect Negative Fare Records
df_taxi.filter(
    F.col("fare_amount") < 0
).select(
    "payment_type",
    "trip_distance",
    "fare_amount",
    "total_amount"
).show(5, truncate=False)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# NYC Taxi Data Cleaning

df_taxi_clean = df_taxi.filter(
    (F.col("trip_distance") > 0) &
    (F.col("fare_amount") > 0) &
    (F.col("tpep_dropoff_datetime") > F.col("tpep_pickup_datetime")) &
    (F.col("tpep_pickup_datetime") >= F.lit("2025-01-01").cast("timestamp_ntz")) &
    (F.col("tpep_pickup_datetime") < F.lit("2026-10-01").cast("timestamp_ntz"))
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df_taxi_clean = df_taxi_clean.dropDuplicates()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Schema Standardization

df_taxi_silver = (
    df_taxi_clean
    .withColumnRenamed("tpep_pickup_datetime", "pickup_datetime")
    .withColumnRenamed("tpep_dropoff_datetime", "dropoff_datetime")
    .withColumnRenamed("PULocationID", "pickup_location_id")
    .withColumnRenamed("DOLocationID", "dropoff_location_id")
    .withColumnRenamed("VendorID", "vendor_id")
    .withColumn("fare_amount", F.col("fare_amount").cast(DecimalType(18, 2)))
    .withColumn("total_amount", F.col("total_amount").cast(DecimalType(18, 2)))
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Date/Time Feature Engineering

df_taxi_silver = (
    df_taxi_silver
    .withColumn(
        "trip_date",
        F.to_date(F.col("pickup_datetime"))
    )
    .withColumn(
        "pickup_hour",
        F.hour(F.col("pickup_datetime"))
    )
    .withColumn(
        "trip_duration_minutes",
        F.round(
            F.expr(
                "timestampdiff(SECOND, pickup_datetime, dropoff_datetime) / 60.0"
            ),
            2
        )
    )
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Inspect Spark Execution Plan

df_taxi_silver.explain("formatted")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Write NYC Taxi Silver Delta Table

(
    df_taxi_silver.write
    .format("delta")
    .mode("overwrite")
    .saveAsTable("dbo.silver_yellow_taxi_trips")
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Validate NYC Taxi Silver Table

df_silver_check = spark.table("dbo.silver_yellow_taxi_trips")

df_silver_check.agg(
    F.count("*").alias("total_clean_trips"),
    F.min("trip_date").alias("first_date"),
    F.max("trip_date").alias("last_date"),
    F.min("trip_duration_minutes").alias("min_duration")
).show(truncate=False)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## NYC Taxi Silver — Validation Results
# 
# - Source: 21 monthly Parquet files (2025-01 to 2026-09)
# - Bronze records: 82,302,001
# - Silver records: 76,069,606
# - Excluded records: 6,232,395 (7.57%)
# - Transformations: filtering, deduplication, schema standardization,
#   date/time feature engineering
# - Output: dbo.silver_yellow_taxi_trips (Delta Table)
# 
# 7.57% of records were excluded through data cleaning and exact deduplication. The contribution of each operation was not measured separately.

# MARKDOWN ********************

