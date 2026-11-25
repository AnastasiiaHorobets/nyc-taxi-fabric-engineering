# Data Dictionary

## Layer overview

| Layer | Object | Grain / purpose |
|---|---|---|
| Bronze | `Files/bronze/yellow_taxi/*.parquet` | Raw monthly Yellow Taxi files |
| Bronze | `bronze_openaq_locations` | Raw OpenAQ locations, sensors, parameters, and measurements |
| Bronze | `bronze_worldbank_gdp` | Raw annual USA GDP observations |
| Bronze | `bronze_ecb_fx_rates` | Raw daily USD/EUR observations |
| Bronze | `Files/bronze/reference/taxi_zone_lookup.csv` | NYC Taxi Zone reference file |
| Silver | `silver_yellow_taxi_trips` | Cleaned individual Taxi trips |
| Silver | `silver_openaq_daily` | Cleaned air-quality measurements prepared for daily Gold aggregation |
| Silver | `silver_worldbank_gdp` | Standardized yearly GDP records |
| Silver | `silver_ecb_fx_rates` | Standardized daily FX records |
| Silver | `silver_taxi_zones` | Standardized Taxi Zone reference |

## Gold Warehouse

### `FactTaxiDaily`

**Grain:** one row per `trip_date` and `pickup_location_id`.

**Business key:** (`trip_date`, `pickup_location_id`).

| Column | Type | Description |
|---|---|---|
| `trip_date` | `DATE` | Pickup calendar date |
| `pickup_location_id` | `INT` | TLC pickup LocationID; joins to `DimZone.location_id` |
| `total_trips` | `INT` | Count of valid Taxi trips |
| `total_revenue_usd` | `DECIMAL(38,2)` | Sum of Taxi `total_amount` in USD |
| `avg_fare_usd` | `DECIMAL(38,6)` | Average base `fare_amount` in USD |
| `avg_trip_distance` | `FLOAT` | Average trip distance |

### `FactAirQualityDaily`

**Grain:** one row per `measurement_date`, `location_id`, `pollutant`, and `units`.

**Business key:** (`measurement_date`, `location_id`, `pollutant`, `units`).

| Column | Type | Description |
|---|---|---|
| `measurement_date` | `DATE` | Air-quality measurement date |
| `location_id` | `BIGINT` | OpenAQ monitoring-location identifier |
| `location_name` | `VARCHAR` | OpenAQ monitoring-location name |
| `pollutant` | `VARCHAR` | Normalized pollutant such as `pm25`, `no2`, or `o3` |
| `units` | `VARCHAR` | Measurement unit; retained in the business key to prevent incompatible aggregation |
| `avg_pollution` | `FLOAT` | Average validated measurement for the fact grain |
| `measurement_count` | `INT` | Number of source measurements represented by the row |

`location_id` is an OpenAQ identifier and does not join to `DimZone`. Taxi zones and air-quality locations are different geographic entities.

### `DimDate`

**Grain/key:** one row per `full_date`.

| Column | Type | Description |
|---|---|---|
| `full_date` | `DATE` | Calendar date |
| `year` | `INT` | Calendar year |
| `month` | `INT` | Calendar month number |
| `day` | `INT` | Calendar day of month |

### `DimZone`

**Grain/key:** one row per TLC `location_id`.

| Column | Type | Description |
|---|---|---|
| `location_id` | `INT` | TLC LocationID |
| `borough` | `VARCHAR` | NYC borough |
| `zone_name` | `VARCHAR` | Taxi Zone name |
| `service_zone` | `VARCHAR` | TLC service-zone classification |

### `DimFX`

**Grain/key:** one row per `fx_date` and `currency`.

| Column | Type | Description |
|---|---|---|
| `fx_date` | `DATE` | ECB observation date |
| `currency` | `VARCHAR` | Quoted currency, currently `USD` |
| `usd_per_eur` | `FLOAT` | USD units per EUR |

For weekends and holidays, the semantic model uses the latest rate on or before the trip date.

### `DimGDP`

**Grain/key:** one row per `country_code` and `year`.

| Column | Type | Description |
|---|---|---|
| `country_code` | `VARCHAR` | ISO country code, currently `USA` |
| `year` | `INT` | Observation year |
| `gdp_usd` | `FLOAT` | Current-price GDP in USD |

## Semantic-model measures

| Measure | Definition / purpose |
|---|---|
| `Average Fare USD` | Trip-weighted average of `avg_fare_usd` using `total_trips` |
| `Revenue EUR` | Converts daily USD revenue using the latest available USD-per-EUR rate |
| `Average Revenue per Trip USD` | Total USD revenue divided by trips within the loaded Taxi period |
| `Average Revenue per Trip EUR` | Converted EUR revenue divided by trips within the loaded Taxi period |
| `ShowLoadedTaxiPeriod` | Returns 1 through the end of the month two months before today; used as a visual filter |

## Relationships

| From | To | Cardinality / purpose |
|---|---|---|
| `DimDate.full_date` | `FactTaxiDaily.trip_date` | One-to-many date filtering |
| `DimDate.full_date` | `FactAirQualityDaily.measurement_date` | One-to-many date filtering |
| `DimZone.location_id` | `FactTaxiDaily.pickup_location_id` | One-to-many pickup-zone filtering |

`DimFX` is evaluated by DAX according to date and currency rather than through a direct daily relationship. `DimGDP` supplies independent annual macroeconomic context.

