[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "worldbank_gdp_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "country_code", DestinationColumnName = "country_code"], [SourceColumnName = "year", DestinationColumnName = "year"], [SourceColumnName = "gdp_usd", DestinationColumnName = "gdp_usd"], [SourceColumnName = "indicator_code", DestinationColumnName = "indicator_code"], [SourceColumnName = "indicator_name", DestinationColumnName = "indicator_name"]}], DynamicSchema = true, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared worldbank_gdp = let
    Source = Json.Document(
        Web.Contents(
            "https://api.worldbank.org",
            [
                RelativePath = "v2/country/USA/indicator/NY.GDP.MKTP.CD",
                Query = [
                    format = "json",
                    date = "2020:2025",
                    per_page = "1000"
                ]
            ]
        )
    ),

    Records = Source{1},

    Data = Table.FromRecords(Records),

    SelectedColumns = Table.SelectColumns(
        Data,
        {
            "countryiso3code",
            "date",
            "value",
            "indicator"
        }
    ),

    ExpandedIndicator = Table.ExpandRecordColumn(
        SelectedColumns,
        "indicator",
        {"id", "value"},
        {"indicator_code", "indicator_name"}
    ),

    RenamedColumns = Table.RenameColumns(
        ExpandedIndicator,
        {
            {"countryiso3code", "country_code"},
            {"date", "year"},
            {"value", "gdp_usd"}
        }
    ),

    ChangedTypes = Table.TransformColumnTypes(
        RenamedColumns,
        {
            {"country_code", type text},
            {"year", Int64.Type},
            {"gdp_usd", type number},
            {"indicator_code", type text},
            {"indicator_name", type text}
        }
    )
in
    ChangedTypes;
shared worldbank_gdp_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true]),
  Navigation_1 = Pattern{[workspaceId = "d517c4eb-a231-41fc-88a3-8e5812b39506"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "7f2bb0a7-1483-4d0c-a91b-0d4ad287ed43"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "bronze_worldbank_gdp", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
