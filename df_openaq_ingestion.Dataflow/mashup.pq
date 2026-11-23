[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[Description = "OpenAQ API key supplied at runtime"]
shared API_SECRET = "PLACEHOLDER" meta [IsParameterQuery = true, IsParameterQueryRequired = false, Type = type text];
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "bronze_openaq_locations_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared bronze_openaq_locations = let
    BaseUrl = "https://api.openaq.org",
    PageSize = 100,

    EmptyTable = #table(
        type table [
            id = nullable number,
            name = nullable text,
            latitude = nullable number,
            longitude = nullable number
        ],
        {}
    ),

    GetPage = (PageNumber as number) as list =>
        let
            Response = Web.Contents(
                BaseUrl,
                [
                    RelativePath = "v3/locations",
                    Query = [
                        coordinates = "40.7128,-74.0060",
                        radius = "25000",
                        limit = Text.From(PageSize),
                        page = Text.From(PageNumber)
                    ],
                    Headers = [
                        #"X-API-Key" = API_SECRET
                    ]
                ]
            ),
            JsonResponse = Json.Document(Response),
            Results = JsonResponse[results]
        in
            Results,

    LocationsTable =
        if API_SECRET = null
            or API_SECRET = ""
            or API_SECRET = "PLACEHOLDER"
        then
            EmptyTable
        else
            let
                Pages = List.Generate(
                    () => [
                        Page = 1,
                        Data = GetPage(1)
                    ],
                    each List.Count([Data]) > 0,
                    each [
                        Page = [Page] + 1,
                        Data = GetPage([Page] + 1)
                    ],
                    each [Data]
                ),

                AllResults = List.Combine(Pages),

                Rows = List.Transform(
                    AllResults,
                    each {
                        _[id],
                        _[name],
                        try _[coordinates][latitude]
                            otherwise null,
                        try _[coordinates][longitude]
                            otherwise null
                    }
                ),

                Data = #table(
                    Value.Type(EmptyTable),
                    Rows
                ),

                UniqueLocations = Table.Distinct(
                    Data,
                    {"id"}
                )
            in
                UniqueLocations
in
    LocationsTable;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "openaq_daily_measurements_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "sensor_id", DestinationColumnName = "sensor_id"], [SourceColumnName = "pollutant", DestinationColumnName = "pollutant"], [SourceColumnName = "units", DestinationColumnName = "units"], [SourceColumnName = "date_from", DestinationColumnName = "date_from"], [SourceColumnName = "date_to", DestinationColumnName = "date_to"], [SourceColumnName = "value", DestinationColumnName = "value"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared openaq_daily_measurements = let
    Sensors = Table.Buffer(
        Table.Distinct(
            Table.SelectColumns(
                Table.SelectRows(
                    openaq_sensors,
                    each [pollutant] <> null
                        and List.Contains(
                            {"pm25", "no2", "o3"},
                            Text.Lower(Text.Trim([pollutant]))
                        )
                ),
                {"sensor_id", "pollutant"}
            ),
            {"sensor_id"}
        )
    ),

    // Keep historical start date
    StartDate = #date(2025, 1, 1),

    // Automatically use yesterday (UTC)
    EndDate = Date.AddDays(
        Date.From(DateTimeZone.FixedUtcNow()),
        -1
    ),

    EmptyTable = #table(
        type table [
            sensor_id = Int64.Type,
            pollutant = nullable text,
            units = nullable text,
            date_from = nullable text,
            date_to = nullable text,
            value = nullable number
        ],
        {}
    ),

    Result =
        if API_SECRET = null
            or API_SECRET = ""
            or API_SECRET = "PLACEHOLDER"
        then
            EmptyTable
        else
            let
                AddMeasurements = Table.AddColumn(
                    Sensors,
                    "measurements",
                    each fnGetDailyMeasurements(
                        [sensor_id],
                        StartDate,
                        EndDate
                    )
                ),

                MeasurementTables =
                    AddMeasurements[measurements],

                Combined =
                    if List.IsEmpty(MeasurementTables)
                    then EmptyTable
                    else Table.Combine(
                        MeasurementTables
                    ),

                RemoveDuplicates = Table.Distinct(
                    Combined,
                    {
                        "sensor_id",
                        "pollutant",
                        "date_from",
                        "date_to"
                    }
                )
            in
                RemoveDuplicates
in
    Result;
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true]),
  Navigation = Source{[workspaceId = "d517c4eb-a231-41fc-88a3-8e5812b39506"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "7f2bb0a7-1483-4d0c-a91b-0d4ad287ed43"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "dbo", ItemKind = "Schema"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared openaq_sensors = let
    BaseUrl = "https://api.openaq.org",
    PageSize = 100,

    EmptyTable = #table(
        type table [
            location_id = nullable number,
            location_name = nullable text,
            sensor_id = nullable number,
            pollutant = nullable text,
            units = nullable text
        ],
        {}
    ),

    GetPage = (PageNumber as number) as list =>
        let
            Response = Web.Contents(
                BaseUrl,
                [
                    RelativePath = "v3/locations",
                    Query = [
                        coordinates = "40.7128,-74.0060",
                        radius = "25000",
                        limit = Text.From(PageSize),
                        page = Text.From(PageNumber),
                        order_by = "id",
                        sort_order = "asc"
                    ],
                    Headers = [
                        #"X-API-Key" = API_SECRET
                    ]
                ]
            ),

            JsonResponse = Json.Document(Response),
            Results = JsonResponse[results]
        in
            Results,

    SensorsTable =
        if API_SECRET = null
            or API_SECRET = ""
            or API_SECRET = "PLACEHOLDER"
        then
            EmptyTable
        else
            let
                Pages = List.Generate(
                    () => [
                        Page = 1,
                        Data = GetPage(1)
                    ],
                    each List.Count([Data]) > 0,
                    each [
                        Page = [Page] + 1,
                        Data = GetPage([Page] + 1)
                    ],
                    each [Data]
                ),

                Locations = List.Combine(Pages),

                SensorRecords = List.Combine(
                    List.Transform(
                        Locations,
                        (loc) =>
                            List.Transform(
                                try loc[sensors] otherwise {},
                                (sensor) => [
                                    location_id = loc[id],
                                    location_name = loc[name],
                                    sensor_id = sensor[id],
                                    pollutant =
                                        try sensor[parameter][name]
                                        otherwise null,
                                    units =
                                        try sensor[parameter][units]
                                        otherwise null
                                ]
                            )
                    )
                ),

                Data = Table.FromRecords(
                    SensorRecords,
                    Value.Type(EmptyTable),
                    MissingField.UseNull
                ),

                UniqueSensors = Table.Distinct(
                    Data,
                    {"location_id", "sensor_id"}
                )
            in
                UniqueSensors
in
    SensorsTable;
[BindToDefaultDestination = true]
shared fnGetDailyMeasurements = (sensor_id as number, date_from as date, date_to as date) =>
let
    SensorIdText = Text.From(sensor_id),
    StartDate = Date.ToText(date_from, "yyyy-MM-dd"),
    EndDate = Date.ToText(date_to, "yyyy-MM-dd"),

    PageSize = 1000,

    EmptyTable = #table(
        type table [
            sensor_id = Int64.Type,
            pollutant = nullable text,
            units = nullable text,
            date_from = nullable text,
            date_to = nullable text,
            value = nullable number
        ],
        {}
    ),

    GetPage = (PageNumber as number) as record =>
        Json.Document(
            Web.Contents(
                "https://api.openaq.org",
                [
                    RelativePath =
                        "v3/sensors/" & SensorIdText & "/days",
                    Query = [
                        date_from = StartDate,
                        date_to = EndDate,
                        limit = Text.From(PageSize),
                        page = Text.From(PageNumber)
                    ],
                    Headers = [
                        #"X-API-Key" = API_SECRET
                    ]
                ]
            )
        ),

    Result =
        if API_SECRET = null
            or API_SECRET = ""
            or API_SECRET = "PLACEHOLDER"
        then
            EmptyTable
        else
            let
 
                Pages =
                    List.Generate(
                        () => [Page = 1, Response = GetPage(1)],
                        each List.Count([Response][results]) > 0,
                        each [
                            Page = [Page] + 1,
                            Response = GetPage([Page] + 1)
                        ],
                        each [Response][results]
                    ),

                Measurements = List.Combine(Pages),

                Rows =
                    List.Transform(
                        Measurements,
                        each {
                            Int64.From(sensor_id),
                            _[parameter][name],
                            _[parameter][units],
                            _[period][datetimeFrom][local],
                            _[period][datetimeTo][local],
                            _[value]
                        }
                    ),

                Data = #table(
                    Value.Type(EmptyTable),
                    Rows
                )
            in
                Data
in
    Result;
shared bronze_openaq_locations_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true]),
  Navigation_1 = Pattern{[workspaceId = "d517c4eb-a231-41fc-88a3-8e5812b39506"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "7f2bb0a7-1483-4d0c-a91b-0d4ad287ed43"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "bronze_openaq_locations", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared openaq_daily_measurements_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "d517c4eb-a231-41fc-88a3-8e5812b39506"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "7f2bb0a7-1483-4d0c-a91b-0d4ad287ed43"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "openaq_daily_measurements", ItemKind = "Table"]}[Data]
in
  TableNavigation;
