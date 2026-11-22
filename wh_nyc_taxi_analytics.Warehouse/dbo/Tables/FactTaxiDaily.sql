CREATE TABLE [dbo].[FactTaxiDaily] (
    [trip_date]          DATE            NULL,
    [pickup_location_id] INT             NULL,
    [total_trips]        INT             NULL,
    [total_revenue_usd]  DECIMAL (38, 2) NULL,
    [avg_fare_usd]       DECIMAL (38, 6) NULL,
    [avg_trip_distance]  FLOAT (53)      NULL
);


GO