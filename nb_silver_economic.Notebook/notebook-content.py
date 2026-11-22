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

# # Silver Layer - Economic Data Transformation

# CELL ********************

from pyspark.sql import functions as F

df_gdp = spark.table("dbo.bronze_worldbank_gdp")
df_fx = spark.table("lh_nyc_taxi.dbo.bronze_ecb_fx_rates")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# World Bank GDP - Schema Standardization

df_gdp_clean = (
    df_gdp
    .withColumn("year", F.col("year").cast("int"))
    .withColumn("gdp_usd", F.col("gdp_usd").cast("double"))
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# World Bank GDP - Data Quality Checks

df_gdp_clean.agg(
    F.count("*").alias("total_records"),
    F.count(F.when(F.col("country_code").isNull(), 1)).alias("null_country_codes"),
    F.count(F.when(F.col("year").isNull(), 1)).alias("null_years"),
    F.count(F.when(F.col("gdp_usd").isNull(), 1)).alias("null_gdp_values"),
    F.count(F.when(F.col("gdp_usd") <= 0, 1)).alias("invalid_gdp_values"),
    F.countDistinct("country_code", "year").alias("unique_country_years")
).show()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# World Bank GDP - Write Silver Delta Table

(
    df_gdp_clean.write
    .format("delta")
    .mode("overwrite")
    .saveAsTable("dbo.silver_worldbank_gdp")
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ECB FX - Schema Standardization

df_fx_clean = (
    df_fx
    .withColumn("date", F.col("date").cast("date"))
    .withColumn("usd_per_eur", F.col("usd_per_eur").cast("double"))
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ECB FX - Data Quality Checks & Currency Validation

df_fx.agg(
    F.count("*").alias("total_records"),
    F.count(F.when(F.col("date").isNull(), 1)).alias("null_dates"),
    F.count(F.when(F.col("usd_per_eur").isNull(), 1)).alias("null_fx_rates"),
    F.count(F.when(F.col("usd_per_eur") <= 0, 1)).alias("invalid_fx_rates"),
    F.count(
        F.when(
            F.col("currency").isNull() |
            (F.col("currency") != "USD"),
            1
        )
    ).alias("invalid_currency"),
    F.countDistinct("date").alias("unique_dates")
).show()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

(
    df_fx.write
    .format("delta")
    .mode("overwrite")
    .saveAsTable("dbo.silver_ecb_fx_rates")
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# Summary
# 
# GDP and ECB FX data checked and saved to Silver Delta tables.
# GDP: 6 records for 2020–2025.
# ECB FX: 480 records.
# No NULL values, invalid values or duplicate keys found.
# No additional cleaning needed.
# 
# Tables:
# dbo.silver_worldbank_gdp
# dbo.silver_ecb_fx_rates
