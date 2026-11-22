CREATE TABLE [dbo].[FactAirQualityDaily] (
    [measurement_date]  DATE           NULL,
    [location_id]       BIGINT         NULL,
    [location_name]     VARCHAR (8000) NULL,
    [pollutant]         VARCHAR (8000) NULL,
    [units]             VARCHAR (8000) NULL,
    [avg_pollution]     FLOAT (53)     NULL,
    [measurement_count] INT            NULL
);


GO