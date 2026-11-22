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


from pyspark.sql.functions import col

df_zones = (
    spark.read
    .option("header", True)
    .option("inferSchema", True)
    .csv("Files/bronze/reference/taxi_zone_lookup.csv")
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df_zones.printSchema()
df_zones.show(5)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df_zones = df_zones.select(
    col("LocationID").alias("location_id"),
    col("Borough").alias("borough"),
    col("Zone").alias("zone_name"),
    col("service_zone")
)

df_zones.write.mode("overwrite").format("delta").saveAsTable("silver_taxi_zones")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
