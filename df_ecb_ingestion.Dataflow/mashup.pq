[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "ecb_fx_rates_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "date", DestinationColumnName = "date"], [SourceColumnName = "usd_per_eur", DestinationColumnName = "usd_per_eur"], [SourceColumnName = "currency", DestinationColumnName = "currency"]}], DynamicSchema = true, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared ecb_fx_rates = let
    Source = Csv.Document(
        Web.Contents(
            "https://data-api.ecb.europa.eu",
            [
                RelativePath = "service/data/EXR/D.USD.EUR.SP00.A",
                Query = [
                    format = "csvdata",
                    startPeriod = "2025-01-01",
                    endPeriod = "2026-11-17"
                ]
            ]
        ),
        [
            Delimiter = ",",
            Encoding = 65001,
            QuoteStyle = QuoteStyle.Csv
        ]
    ),

    Headers = Table.PromoteHeaders(
        Source,
        [PromoteAllScalars = true]
    ),

    SelectedColumns = Table.SelectColumns(
        Headers,
        {"TIME_PERIOD", "OBS_VALUE"}
    ),

    RenamedColumns = Table.RenameColumns(
        SelectedColumns,
        {
            {"TIME_PERIOD", "date"},
            {"OBS_VALUE", "usd_per_eur"}
        }
    ),

    ChangedTypes = Table.TransformColumnTypes(
        RenamedColumns,
        {
            {"date", type date},
            {"usd_per_eur", type number}
        },
        "en-US"
    ),

    AddedCurrency = Table.AddColumn(
        ChangedTypes,
        "currency",
        each "USD",
        type text
    )
in
    AddedCurrency;
shared ecb_fx_rates_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true]),
  Navigation_1 = Pattern{[workspaceId = "d517c4eb-a231-41fc-88a3-8e5812b39506"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "7f2bb0a7-1483-4d0c-a91b-0d4ad287ed43"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "bronze_ecb_fx_rates", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
