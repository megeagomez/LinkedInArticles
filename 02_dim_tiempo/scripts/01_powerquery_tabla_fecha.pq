// Tabla de fechas — Power Query M (v2)
// Requiere que existan en el modelo los parámetros:
//   _StartYear         (Number)  p.ej. 2019
//   _EndYear           (Number)  p.ej. 2025
//   _FiscalStartMonth  (Number)  p.ej. 6   (mes en que arranca el año fiscal)
//   _FiscalYearBasis   (Text)    "Start" o "End" — ver más abajo
// ============================================================================
// CAMBIOS v1 -> v1 (bugs pedidos/encontrados, ver artículo para el detalle):
//  1) [BUG PEDIDO] "Current Day" comparaba [Date] (datetime) contra
//     Date.From(DateTime.LocalNow()) (date) con "=" sin normalizar el lado
//     izquierdo. Fix: Date.From([Date]) en los dos lados.
//  2) [BUG EXTRA] "Current Week" comparaba [Month] contra Date.WeekOfYear(Now()).
//     Fix: comparar contra [Week of Year].
//  3) [BUG EXTRA] "DayOffset" restaba DateTime.LocalNow() (con hora) a [Date]
//     (medianoche); Duration.Days truncaba hacia cero. Fix: normalizar los dos
//     lados con Date.From() antes de restar.
//  4) [INCONSISTENCIA] "idFecha" tenía una errata de pegado ([Month]+100+[Day]);
//     la fórmula correcta es [Month]*100+[Day].
//
// CAMBIOS v1 -> v2 (auditoría de reusabilidad, ver artículo):
//  5) [GAP] "FiscalYear" usaba Date.Year(Date.AddMonths([Date],-FiscalStartMonth)),
//     una fórmula que desplaza el mes pero no dice con qué convención se nombra
//     el año fiscal (¿junio de 2025 es FY2025 o FY2026? dependía de leer la
//     fórmula, no de una decisión explícita). Fix: FiscalYear ahora se calcula
//     a partir del año calendario en que ARRANCA el año fiscal, y un parámetro
//     _FiscalYearBasis decide si se etiqueta por el año de inicio ("Start") o
//     por el año de fin ("End"). "Current Fiscal Year" se recalculó con la
//     misma fórmula para que la comparación sea consistente.
//  6) [NUEVO] FiscalQuarter / FiscalQuarterCode: no existían. El trimestre
//     fiscal ahora se deriva de _FiscalStartMonth igual que el año fiscal, en
//     vez de asumir que el trimestre fiscal coincide con el natural.
//  7) [NUEVO] IsWorkingDay / WorkingDayNumber: día laborable (de lunes a
//     viernes) y contador secuencial de días laborables dentro de cada año
//     natural — para SLAs y productividad real. No contempla festivos: en
//     España hay nacionales, autonómicos y locales, así que esa lógica se
//     resuelve aparte (tabla de festivos por calendario, cruzada donde haga
//     falta), no dentro de la dimensión de tiempo.
// ============================================================================

let
    Source = List.Dates(#date(_StartYear,1,1), Duration.Days(#date(_EndYear+1,1,1) - #date(_StartYear,1,1)), #duration(1,0,0,0)),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Changed Type" = Table.TransformColumnTypes(#"Converted to Table",{{"Column1", type datetime}}),
    #"Sorted Rows" = Table.Sort(#"Changed Type",{{"Column1", Order.Ascending}}),
    #"Renamed Columns" = Table.RenameColumns(#"Sorted Rows",{{"Column1", "Date"}}),
    #"Inserted Year" = Table.AddColumn(#"Renamed Columns", "Year", each Date.Year([Date]), Int64.Type),
    #"Inserted Month" = Table.AddColumn(#"Inserted Year", "Month", each Date.Month([Date]), Int64.Type),
    #"Inserted Month Name" = Table.AddColumn(#"Inserted Month", "Month Name", each Date.MonthName([Date]), type text),
    #"Inserted Month Name Short" = Table.AddColumn(#"Inserted Month Name", "Month Name Short", each Text.Start([Month Name],3)),
    #"Inserted Mont Name Complete" = Table.AddColumn(#"Inserted Month Name Short", "Month Name Complete", each [Month Name] & " " & Text.From([Year])),
    #"Inserted Month Name Short Complete" = Table.AddColumn(#"Inserted Mont Name Complete", "Month Name Short Complete", each [Month Name Short] & " " & Text.End(Text.From([Year]),2)),
    #"Changed Type6" = Table.TransformColumnTypes(#"Inserted Month Name Short Complete",{{"Month Name Short", type text},{"Month Name Complete", type text},{"Month Name Short Complete", type text}}),
    #"Inserted Days in Month" = Table.AddColumn(#"Changed Type6", "Days in Month", each Date.DaysInMonth([Date]), Int64.Type),
    #"Removed Columns" = Table.RemoveColumns(#"Inserted Days in Month",{"Days in Month"}),
    #"Inserted Quarter" = Table.AddColumn(#"Removed Columns", "Quarter", each Date.QuarterOfYear([Date]), Int64.Type),
    #"Inserted Week of Year" = Table.AddColumn(#"Inserted Quarter", "Week of Year", each Date.WeekOfYear([Date]), Int64.Type),
    #"Inserted Day" = Table.AddColumn(#"Inserted Week of Year", "Day", each Date.Day([Date]), Int64.Type),
    #"Inserted Day of Week" = Table.AddColumn(#"Inserted Day", "Day of Week", each Date.DayOfWeek([Date]), Int64.Type),
    #"Fecha key" = Table.AddColumn(#"Inserted Day of Week", "idFecha", each [Year]*10000+[Month]*100+[Day]),
    #"Changed Type3" = Table.TransformColumnTypes(#"Fecha key",{{"idFecha", Int64.Type}}),
    #"Added Custom4" = Table.AddColumn(#"Changed Type3", "MonthKey", each [Year]*100+[Month]),
    #"Changed Type4" = Table.TransformColumnTypes(#"Added Custom4",{{"MonthKey", Int64.Type}}),
    #"Added Custom5" = Table.AddColumn(#"Changed Type4", "QuarterCode", each [Year]*100 + (if [Month] <=3 then 1 else if [Month]<=6 then 2 else if [Month]<=9 then 3 else 4)),
    #"Changed Type5" = Table.TransformColumnTypes(#"Added Custom5",{{"QuarterCode", Int64.Type}}),
    #"Inserted Day of Year" = Table.AddColumn(#"Changed Type5", "Day of Year", each Date.DayOfYear([Date]), Int64.Type),
    #"Inserted Day Name" = Table.AddColumn(#"Inserted Day of Year", "Day Name", each Date.DayOfWeekName([Date]), type text),
    #"Added Custom" = Table.AddColumn(#"Inserted Day Name", "FiscalDate", each Date.AddMonths([Date],-1*_FiscalStartMonth)),
    #"Changed Type1" = Table.TransformColumnTypes(#"Added Custom",{{"FiscalDate", type datetime}}),
    #"Fiscal week of Year" = Table.AddColumn(#"Changed Type1", "Fiscal Week of Year", each Date.WeekOfYear([FiscalDate]), Int64.Type),

    // --- Año/trimestre fiscal: explícitos y parametrizables (ver cambio 5 y 6) ---
    #"FiscalYearStart" = Table.AddColumn(#"Fiscal week of Year", "FiscalYearStart", each if [Month] >= _FiscalStartMonth then [Year] else [Year] - 1, Int64.Type),
    #"FiscalYear" = Table.AddColumn(#"FiscalYearStart", "FiscalYear", each if _FiscalYearBasis = "End" then [FiscalYearStart] + 1 else [FiscalYearStart], Int64.Type),
    #"FiscalQuarter" = Table.AddColumn(#"FiscalYear", "FiscalQuarter", each Number.IntegerDivide(Number.Mod([Month] - _FiscalStartMonth, 12), 3) + 1, Int64.Type),
    #"FiscalQuarterCode" = Table.AddColumn(#"FiscalQuarter", "FiscalQuarterCode", each [FiscalYear]*100 + [FiscalQuarter], Int64.Type),
    #"RemovedFiscalYearStart" = Table.RemoveColumns(#"FiscalQuarterCode", {"FiscalYearStart"}),

    #"CurrentYear" = Table.AddColumn(#"RemovedFiscalYearStart", "Current Year", each if [Year]=Date.Year(DateTime.LocalNow()) then "Current" else if [Year]>Date.Year(DateTime.LocalNow()) then "Future Year" else "Past Year"),
    #"CurrentMonth" = Table.AddColumn(CurrentYear, "Current Month", each if [Year]*100+[Month] = Date.Year(DateTime.LocalNow()) *100+ Date.Month(DateTime.LocalNow())   then "Current" else if  [Year]*100+[Month] > Date.Year(DateTime.LocalNow()) *100+ Date.Month(DateTime.LocalNow())  then "Future Month" else "Past Month"),
    #"CurrentWeek" = Table.AddColumn(CurrentMonth, "Current Week", each if [Year]*100+[Week of Year] = Date.Year(DateTime.LocalNow()) *100+ Date.WeekOfYear(DateTime.LocalNow())   then "Current" else if  [Year]*100+[Week of Year] > Date.Year(DateTime.LocalNow()) *100+ Date.WeekOfYear(DateTime.LocalNow())  then "Future Week" else "Past Week"),
    #"CurrentDay" = Table.AddColumn(CurrentWeek, "Current Day", each if Date.From([Date])=Date.From(DateTime.LocalNow()) then "Current" else if Date.From([Date])>=Date.From(DateTime.LocalNow()) then "Future Day" else "Past Day"),

    // "hoy" recalculado con la misma fórmula que FiscalYear, para que la
    // comparación sea consistente con el cambio 5 (antes usaba el truco de
    // Date.AddMonths, que ya no es la fuente de verdad de FiscalYear).
    #"CurrentFiscalYear" = Table.AddColumn(CurrentDay, "Current Fiscal Year", each
        let
            todayMonth = Date.Month(DateTime.LocalNow()),
            todayYear = Date.Year(DateTime.LocalNow()),
            todayFiscalYearStart = if todayMonth >= _FiscalStartMonth then todayYear else todayYear - 1,
            todayFiscalYear = if _FiscalYearBasis = "End" then todayFiscalYearStart + 1 else todayFiscalYearStart
        in
            if [FiscalYear] = todayFiscalYear then "Current"
            else if [FiscalYear] > todayFiscalYear then "Future Year"
            else "Past Year"
    ),
    #"CurrentFiscalMonth" = Table.AddColumn(CurrentFiscalYear, "Current Fiscal Month", each [Current Month]),
    #"CurrentFiscalWeek" = Table.AddColumn(CurrentFiscalMonth, "Current Fiscal Week", each [Current Week]),
       ObtenIsoWeek= (Fecha as date) => let
                    #"Removed Other Columns" = Table.FromRows({{Fecha}},{"FullDateAlternateKey"}),
                    #"Added Custom" = Table.AddColumn(#"Removed Other Columns", "PrimerDiaAño", each Date.AddDays( #date(Date.Year([FullDateAlternateKey]),1,4) ,-1* Date.DayOfWeek(  #date(Date.Year([FullDateAlternateKey]),1,4),Day.Monday))),
                    #"Added Custom1" = Table.AddColumn(#"Added Custom", "PrimerDiaAnioAA", each Date.AddDays( #date(Date.Year([FullDateAlternateKey])-1,1,4) ,-1* Date.DayOfWeek(  #date(Date.Year([FullDateAlternateKey])-1,1,4),Day.Monday))),
                    #"Added Custom2" = Table.AddColumn(#"Added Custom1", "PrimerDiaAnioSig", each Date.AddDays( #date(1+Date.Year([FullDateAlternateKey]),1,4) ,-1* Date.DayOfWeek(  #date(1+Date.Year([FullDateAlternateKey]),1,4),Day.Monday))),
                    #"Changed Type" = Table.TransformColumnTypes(#"Added Custom2",{{"PrimerDiaAño", type date}, {"PrimerDiaAnioAA", type date}, {"PrimerDiaAnioSig", type date}}),
                    #"Added Custom3" = Table.AddColumn(#"Changed Type", "AnioNatural", each Date.Year([FullDateAlternateKey])),
                    #"Added Conditional Column" = Table.AddColumn(#"Added Custom3", "Custom", each if [FullDateAlternateKey] >= [PrimerDiaAnioSig] then [AnioNatural] +1 else if [FullDateAlternateKey] >= [PrimerDiaAño] then [AnioNatural]  else [AnioNatural] -1 ),
                    #"Sorted Rows" = Table.Sort(#"Added Conditional Column",{{"FullDateAlternateKey", Order.Descending}}),
                    #"Renamed Columns" = Table.RenameColumns(#"Sorted Rows",{{"Custom", "IsoYear"}}),
                    #"Changed Type1" = Table.TransformColumnTypes(#"Renamed Columns",{{"IsoYear", Int64.Type}}),
                    #"Added Custom4" = Table.AddColumn(#"Changed Type1", "IsoWeek", each if [FullDateAlternateKey] >= [PrimerDiaAnioSig] then 1 else if [FullDateAlternateKey] >= [PrimerDiaAño] then 1+Number.RoundDown ( Duration.Days ([FullDateAlternateKey]-[PrimerDiaAño])/7 )  else 1+ Number.RoundDown ( Duration.Days ([FullDateAlternateKey]-Date.AddDays( #date(Date.Year([FullDateAlternateKey])-1,1,4) ,-1* Date.DayOfWeek(  #date(Date.Year([FullDateAlternateKey])-1,1,4),Day.Monday)))/7 )),
                        #"Removed Other Columns1" = Table.SelectColumns(#"Added Custom4",{"FullDateAlternateKey", "IsoYear", "IsoWeek"})

                    in
                        #"Removed Other Columns1" ,
    #"AniadirIsoWeek"=Table.AddColumn( #"CurrentFiscalWeek","DatosIso",each ObtenIsoWeek( Date.From( [Date]))),
    #"Expanded DatosIso" = Table.ExpandTableColumn(AniadirIsoWeek, "DatosIso", {"IsoYear", "IsoWeek"}, {"IsoYear", "IsoWeek"}),
   #"Added Custom1" = Table.AddColumn(#"Expanded DatosIso", "DayOffset", each Duration.Days(Date.From([Date])-Date.From(DateTime.LocalNow()))),
    #"Added Custom2" = Table.AddColumn(#"Added Custom1", "YearOffset", each [Year]- Date.Year(DateTime.LocalNow())),
    #"Added Custom3" = Table.AddColumn(#"Added Custom2", "MonthOffset", each -1* (  (12 - [Month]) + (-[YearOffset]-1)*12 + Date.Month(DateTime.LocalNow()) )),
    #"Added Custom6" = Table.AddColumn(#"Added Custom3", "QuarterOffset", each -1* (  (4 - [Quarter]) + (-[YearOffset]-1)*4 + Date.QuarterOfYear(DateTime.LocalNow()) )),

    // --- Día laborable (cambio 7): de lunes a viernes; festivos se resuelven aparte ---
    #"Added IsWorkingDay" = Table.AddColumn(#"Added Custom6", "IsWorkingDay", each
        [Day of Week] <> 0 and [Day of Week] <> 6
    ),

    // Contador de días laborables dentro de cada año natural (acumulado "a
    // fecha de"): agrupa por Year, ordena por Date y suma 1/0 corriendo con
    // List.Generate (Power Query no tiene una primitiva nativa de "running
    // total"; este es el patrón estándar para simularla en O(n) por grupo).
    #"Added WorkingDayNumber" =
        let
            grouped = Table.Group(#"Added IsWorkingDay", {"Year"}, {{"Rows", each
                let
                    sorted = Table.Sort(_, {{"Date", Order.Ascending}}),
                    n = Table.RowCount(sorted),
                    flags = Table.Column(sorted, "IsWorkingDay"),
                    running = List.Generate(
                        () => [i = 0, acc = 0],
                        each [i] < n,
                        each [i = [i] + 1, acc = [acc] + (if flags{[i]} then 1 else 0)],
                        each [acc] + (if flags{[i]} then 1 else 0)
                    )
                in
                    Table.FromColumns(Table.ToColumns(sorted) & {running}, Table.ColumnNames(sorted) & {"WorkingDayNumber"})
            , type table}}),
            combined = Table.Sort(Table.Combine(grouped[Rows]), {{"Date", Order.Ascending}})
        in
            combined,

    #"Changed Type2" = Table.TransformColumnTypes(#"Added WorkingDayNumber",{{"DayOffset", Int64.Type}, {"IsoWeek", Int64.Type}, {"IsoYear", Int64.Type}, {"YearOffset", Int64.Type},{"QuarterOffset", Int64.Type},  {"MonthOffset", Int64.Type}, {"Current Year", type text}, {"Current Month", type text}, {"Current Week", type text}, {"Current Day", type text}, {"Current Fiscal Year", type text}, {"Current Fiscal Month", type text}, {"Current Fiscal Week", type text}, {"IsWorkingDay", type logical}, {"WorkingDayNumber", Int64.Type}})

in
   #"Changed Type2"
