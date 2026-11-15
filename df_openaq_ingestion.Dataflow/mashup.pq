[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[Description = "OpenAQ API key supplied at runtime"]
shared API_SECRET = "PLACEHOLDER" meta [IsParameterQuery = true, IsParameterQueryRequired = false, Type = type text];
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "openaq_measurements_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared bronze_openaq_locations = let
    BaseUrl = "https://api.openaq.org",

    EmptyTable = #table(
        type table [
            id = nullable number,
            name = nullable text,
            latitude = nullable number,
            longitude = nullable number
        ],
        {}
    ),

    LocationsTable =
        if API_SECRET = null
            or API_SECRET = ""
            or API_SECRET = "PLACEHOLDER"
        then
            EmptyTable
        else
            let
                Response = Web.Contents(
                    BaseUrl,
                    [
                        RelativePath = "v3/locations",
                        Query = [
                            coordinates = "40.7128,-74.0060",
                            radius = "25000",
                            limit = "100",
                            page = "1"
                        ],
                        Headers = [
                            #"X-API-Key" = API_SECRET
                        ]
                    ]
                ),

                JsonResponse = Json.Document(Response),
                Results = JsonResponse[results],

                Rows = List.Transform(
                    Results,
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
                )
            in
                Data
in
    LocationsTable;
[BindToDefaultDestination = true]
shared debug_parameter_check = let
    KeyReceived =
        API_SECRET <> null
        and Text.Length(API_SECRET) > 0
        and API_SECRET <> "PLACEHOLDER",

    Result = #table(
        type table [ParameterReceived = logical],
        {{KeyReceived}}
    )
in
    Result;
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true]),
  Navigation = Source{[workspaceId = "d517c4eb-a231-41fc-88a3-8e5812b39506"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "7f2bb0a7-1483-4d0c-a91b-0d4ad287ed43"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "dbo", ItemKind = "Schema"]}[Data]
in
  #"Navigation 2";
shared openaq_measurements_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true]),
  Navigation_1 = Pattern{[workspaceId = "d517c4eb-a231-41fc-88a3-8e5812b39506"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "7f2bb0a7-1483-4d0c-a91b-0d4ad287ed43"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "openaq_measurements", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[BindToDefaultDestination = true]
shared openaq_sensors = let
    BaseUrl = "https://api.openaq.org",

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

    SensorsTable =
        if API_SECRET = null
            or API_SECRET = ""
            or API_SECRET = "PLACEHOLDER"
        then
            EmptyTable
        else
            let
                Response = Web.Contents(
                    BaseUrl,
                    [
                        RelativePath = "v3/locations",
                        Query = [
                            coordinates = "40.7128,-74.0060",
                            radius = "25000",
                            limit = "100",
                            page = "1"
                        ],
                        Headers = [
                            #"X-API-Key" = API_SECRET
                        ]
                    ]
                ),

                JsonResponse = Json.Document(Response),
                Locations = JsonResponse[results],

                SensorRecords = List.Combine(
                    List.Transform(
                        Locations,
                        (loc) =>
                            List.Transform(
                                loc[sensors],
                                (sensor) => [
                                    location_id = loc[id],
                                    location_name = loc[name],
                                    sensor_id = sensor[id],
                                    pollutant = sensor[parameter][name],
                                    units = sensor[parameter][units]
                                ]
                            )
                    )
                ),

                Data = Table.FromRecords(
                    SensorRecords,
                    Value.Type(EmptyTable),
                    MissingField.UseNull
                )
            in
                Data
in
    SensorsTable;
[BindToDefaultDestination = true]
shared openaq_sensor_coverage = let
    EmptyTable = #table(
        type table [
            sensor_id = nullable number,
            datetime_first = nullable text,
            datetime_last = nullable text
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
                Response = Web.Contents(
                    "https://api.openaq.org",
                    [
                        RelativePath = "v3/sensors/673",
                        Headers = [
                            #"X-API-Key" = API_SECRET
                        ]
                    ]
                ),

                JsonResponse = Json.Document(Response),
                Sensor = JsonResponse[results]{0},

                Data = #table(
                    Value.Type(EmptyTable),
                    {{
                        Sensor[id],
                        Sensor[datetimeFirst][utc],
                        Sensor[datetimeLast][utc]
                    }}
                )
            in
                Data
in
    Result;
[BindToDefaultDestination = true]
shared openaq_daily_measurements = let
    BaseUrl = "https://api.openaq.org",

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
                Response = Web.Contents(
                    BaseUrl,
                    [
                        RelativePath = "v3/sensors/673/days",
                        Query = [
                            date_from = "2026-01-01",
                            date_to = "2026-02-01",
                            limit = "100",
                            page = "1"
                        ],
                        Headers = [
                            #"X-API-Key" = API_SECRET
                        ]
                    ]
                ),

                JsonResponse = Json.Document(Response),
                Measurements = JsonResponse[results],

                Rows = List.Transform(
                    Measurements,
                    each {
                        673,
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
