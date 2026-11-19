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

# CELL ********************

spark.sql("SHOW TABLES in dbo").show(truncate=False)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# **Schema and how many rows**

# CELL ********************

bronze_tables = [
    "bronze_openaq_locations",
    "openaq_sensors",
    "openaq_daily_measurements",
    "bronze_worldbank_gdp",
    "bronze_ecb_fx_rates",

]

for table in bronze_tables:
    df = spark.table(f"dbo.{table}")

    print(f"\nTable: {table}")
    print(f"Rows: {df.count()}")
    df.printSchema()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

taxi_path = "Files/bronze/yellow_taxi"

files = notebookutils.fs.ls(taxi_path)

for file in files:
    print(file.name)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df_taxi = spark.read.parquet(
    "Files/bronze/yellow_taxi/"
)

df_taxi.printSchema()
print(f"Total columns: {len(df_taxi.columns)}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
