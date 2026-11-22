CREATE   PROCEDURE dbo.sp_refresh_fact_air_quality
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.FactAirQualityDaily AS target
    USING (
        SELECT
            measurement_date,
            location_id,
            location_name,
            pollutant,
            units,
            AVG(value) AS avg_pollution,
            COUNT(*) AS measurement_count
        FROM lh_nyc_taxi.dbo.silver_openaq_daily
        WHERE measurement_date >= DATEADD(
            DAY, -13,
            (SELECT MAX(measurement_date)
             FROM lh_nyc_taxi.dbo.silver_openaq_daily)
        )
        GROUP BY
            measurement_date,
            location_id,
            location_name,
            pollutant,
            units
    ) AS source

    ON target.measurement_date = source.measurement_date
       AND target.location_id = source.location_id
       AND target.pollutant = source.pollutant
       AND target.units = source.units

    WHEN MATCHED THEN
        UPDATE SET
            target.location_name = source.location_name,
            target.avg_pollution = source.avg_pollution,
            target.measurement_count = source.measurement_count

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            measurement_date,
            location_id,
            location_name,
            pollutant,
            units,
            avg_pollution,
            measurement_count
        )
        VALUES (
            source.measurement_date,
            source.location_id,
            source.location_name,
            source.pollutant,
            source.units,
            source.avg_pollution,
            source.measurement_count
        );
END;

GO