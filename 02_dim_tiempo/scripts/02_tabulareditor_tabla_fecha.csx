// Script C# para Tabular Editor (menú Advanced Scripting / TE3-TE2).
// Crea/actualiza la tabla de fechas, sus parámetros, jerarquías y la medida "{nombre_tabla}_selection".
// El nombre de la medida incluye el nombre de la tabla porque las medidas son
// únicas en todo el modelo (a diferencia de las columnas, que solo lo son
// dentro de su tabla): si generas más de una dimensión de tiempo con este
// script, "Selection" a secas chocaría con la de la primera.
// Es idempotente: si la tabla, las jerarquías o los parámetros ya existen, no los duplica.
//
// v1 -> v1: mismos tres bugs de M que en el .pq, más uno propio de C#:
//  1) "Current Day": la igualdad comparaba [Date] (datetime) contra Date.From(Now())
//     (date) sin normalizar el lado izquierdo -> hoy podía no marcarse como "Current".
//  2) "Current Week": comparaba [Month] contra Date.WeekOfYear(Now()) en vez de
//     [Week of Year] -> la semana "Current" casi nunca coincidía con la real.
//  3) "DayOffset": restaba DateTime.LocalNow() (con hora) sin normalizar a fecha,
//     así que Duration.Days truncaba y "mañana" podía salir como 0 según la hora
//     de refresco. Se normalizan ambos lados con Date.From() antes de restar.
//  4) [BUG C#, ROMPE EL SCRIPT] tab.Columns["Month Name short"] usaba una "s"
//     minúscula, pero la columna se crea como "Month Name Short" (S mayúscula).
//     El indexador de Columns en Tabular Editor es sensible a mayúsculas, así que
//     esa línea lanzaba una excepción y abortaba el script antes de llegar a las
//     jerarquías y a la medida. Fix: usar el nombre exacto.
//
// v1 -> v2 (auditoría de reusabilidad, ver artículo):
//  5) Año/trimestre fiscal explícitos: nuevo parámetro _FiscalYearBasis
//     ("Start"/"End") y columnas FiscalQuarter / FiscalQuarterCode.
//  6) IsWorkingDay / WorkingDayNumber: día laborable de lunes a viernes y su
//     contador acumulado por año. No contempla festivos (nacionales,
//     autonómicos, locales): esa lógica se resuelve aparte, fuera de la
//     dimensión de tiempo.
//  7) Carpetas reorganizadas con una taxonomía consistente de 5 grupos
//     (Atributos descriptivos / Ordinales / Claves / Posiciones relativas /
//     Días laborables) en vez de la mezcla ad hoc anterior — incluye el fix de
//     QuarterCode, que se había quedado fuera de la carpeta de claves.
//  8) sortByColumn de "Day Name" (no lo tenía) apuntando a "Day of Week".

var tname="Fecha";

var ToTable="foo";
var ToColumn="date";


var CrearFiscal="si";
var CrearSemana="si";
var CrearSemanaFiscal="si";
var CrearIso="si";
/* Fin de variables de comportamiento */

var addexpresion="si";
foreach(var t in Model.Expressions)
{
    if (t.Name=="_StartYear")
        addexpresion="no";
}

if(addexpresion=="si"){
var exp=Model.AddExpression("_StartYear","2019");
exp.Expression="2016  meta [IsParameterQuery=true, Type=\"Number\", IsParameterQueryRequired=true]";
exp.Kind=ExpressionKind.M;
exp=Model.AddExpression("_EndYear","2025");
exp.Expression="2023 meta [IsParameterQuery=true, Type=\"Number\", IsParameterQueryRequired=true]";
exp.Kind=ExpressionKind.M;
exp=Model.AddExpression("_FiscalStartMonth","6");
exp.Expression="6 meta [IsParameterQuery=true, Type=\"Number\", IsParameterQueryRequired=true]";
exp.Kind=ExpressionKind.M;
exp=Model.AddExpression("_FiscalYearBasis","End");
exp.Expression="\"End\" meta [IsParameterQuery=true, Type=\"Text\", IsParameterQueryRequired=true]";
exp.Kind=ExpressionKind.M;

}

var tab2= Model.AddTable();

var tab=Model.Tables[0];

foreach(var t in Model.Tables)
{
    if (t.Name==tname)
    { tab=t;
    }
}

if (tab.Name!=tname)
    tab=Model.AddTable(tname);

tab.DataCategory= "Time";
var partition=tab.Partitions.First();
partition.Query=@"let
    Source =List.Dates(#date(_StartYear,1,1),Duration.Days(#date(_EndYear+1,1,1) -#date(_StartYear,1,1)) ,#duration(1,0,0,0)),
    #""Converted to Table"" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #""Changed Type"" = Table.TransformColumnTypes(#""Converted to Table"",{{""Column1"", type datetime}}),
    #""Sorted Rows"" = Table.Sort(#""Changed Type"",{{""Column1"", Order.Ascending}}),
    #""Renamed Columns"" = Table.RenameColumns(#""Sorted Rows"",{{""Column1"", ""Date""}}),
    #""Inserted Year"" = Table.AddColumn(#""Renamed Columns"", ""Year"", each Date.Year([Date]), Int64.Type),
    #""Inserted Month"" = Table.AddColumn(#""Inserted Year"", ""Month"", each Date.Month([Date]), Int64.Type),
    #""Inserted Month Name"" = Table.AddColumn(#""Inserted Month"", ""Month Name"", each Date.MonthName([Date]), type text),
    #""Inserted Month Name Short"" = Table.AddColumn(#""Inserted Month Name"", ""Month Name Short"", each Text.Start([Month Name],3)),
    #""Inserted Mont Name Complete"" = Table.AddColumn(#""Inserted Month Name Short"", ""Month Name Complete"", each [Month Name] & "" "" & Text.From([Year])),
    #""Inserted Month Name Short Complete"" = Table.AddColumn(#""Inserted Mont Name Complete"", ""Month Name Short Complete"", each [Month Name Short] & "" "" & Text.End(Text.From([Year]),2)),
    #""Changed Type6"" = Table.TransformColumnTypes(#""Inserted Month Name Short Complete"",{{""Month Name Short"", type text},{""Month Name Complete"", type text},{""Month Name Short Complete"", type text}}),
    #""Inserted Days in Month"" = Table.AddColumn(#""Changed Type6"", ""Days in Month"", each Date.DaysInMonth([Date]), Int64.Type),
    #""Removed Columns"" = Table.RemoveColumns(#""Inserted Days in Month"",{""Days in Month""}),
    #""Inserted Quarter"" = Table.AddColumn(#""Removed Columns"", ""Quarter"", each Date.QuarterOfYear([Date]), Int64.Type),
    #""Inserted Week of Year"" = Table.AddColumn(#""Inserted Quarter"", ""Week of Year"", each Date.WeekOfYear([Date]), Int64.Type),
    #""Inserted Day"" = Table.AddColumn(#""Inserted Week of Year"", ""Day"", each Date.Day([Date]), Int64.Type),
    #""Inserted Day of Week"" = Table.AddColumn(#""Inserted Day"", ""Day of Week"", each Date.DayOfWeek([Date]), Int64.Type),
    #""Fecha key"" = Table.AddColumn(#""Inserted Day of Week"", ""idFecha"", each [Year]*10000+[Month]*100+[Day]),
    #""Changed Type3"" = Table.TransformColumnTypes(#""Fecha key"",{{""idFecha"", Int64.Type}}),
    #""Added Custom4"" = Table.AddColumn(#""Changed Type3"", ""MonthKey"", each [Year]*100+[Month]),
    #""Changed Type4"" = Table.TransformColumnTypes(#""Added Custom4"",{{""MonthKey"", Int64.Type}}),
    #""Added Custom5"" = Table.AddColumn(#""Changed Type4"", ""QuarterCode"", each [Year]*100 + (if [Month] <=3 then 1 else if [Month]<=6 then 2 else if [Month]<=9 then 3 else 4)),
    #""Changed Type5"" = Table.TransformColumnTypes(#""Added Custom5"",{{""QuarterCode"", Int64.Type}}),
    #""Inserted Day of Year"" = Table.AddColumn(#""Changed Type5"", ""Day of Year"", each Date.DayOfYear([Date]), Int64.Type),
    #""Inserted Day Name"" = Table.AddColumn(#""Inserted Day of Year"", ""Day Name"", each Date.DayOfWeekName([Date]), type text),
    #""Added Custom"" = Table.AddColumn(#""Inserted Day Name"", ""FiscalDate"", each Date.AddMonths([Date],-1*_FiscalStartMonth)),
    #""Changed Type1"" = Table.TransformColumnTypes(#""Added Custom"",{{""FiscalDate"", type datetime}}),
    #""Fiscal week of Year"" = Table.AddColumn(#""Changed Type1"", ""Fiscal Week of Year"", each Date.WeekOfYear([FiscalDate]), Int64.Type),
    #""FiscalYearStart"" = Table.AddColumn(#""Fiscal week of Year"", ""FiscalYearStart"", each if [Month] >= _FiscalStartMonth then [Year] else [Year] - 1, Int64.Type),
    #""FiscalYear"" = Table.AddColumn(#""FiscalYearStart"", ""FiscalYear"", each if _FiscalYearBasis = ""End"" then [FiscalYearStart] + 1 else [FiscalYearStart], Int64.Type),
    #""FiscalQuarter"" = Table.AddColumn(#""FiscalYear"", ""FiscalQuarter"", each Number.IntegerDivide(Number.Mod([Month] - _FiscalStartMonth, 12), 3) + 1, Int64.Type),
    #""FiscalQuarterCode"" = Table.AddColumn(#""FiscalQuarter"", ""FiscalQuarterCode"", each [FiscalYear]*100 + [FiscalQuarter], Int64.Type),
    #""RemovedFiscalYearStart"" = Table.RemoveColumns(#""FiscalQuarterCode"", {""FiscalYearStart""}),
    #""CurrentYear"" = Table.AddColumn(#""RemovedFiscalYearStart"", ""Current Year"", each if  [Year]=Date.Year(DateTime.LocalNow()) then ""Current"" else if [Year]>Date.Year(DateTime.LocalNow()) then ""Future Year"" else ""Past Year""),
    #""CurrentMonth"" = Table.AddColumn(CurrentYear, ""Current Month"", each if [Year]*100+[Month] = Date.Year(DateTime.LocalNow()) *100+ Date.Month(DateTime.LocalNow())   then ""Current"" else if  [Year]*100+[Month] > Date.Year(DateTime.LocalNow()) *100+ Date.Month(DateTime.LocalNow())  then ""Future Month"" else ""Past Month""),
    #""CurrentWeek"" = Table.AddColumn(CurrentMonth, ""Current Week"", each if [Year]*100+[Week of Year] = Date.Year(DateTime.LocalNow()) *100+ Date.WeekOfYear(DateTime.LocalNow())   then ""Current"" else if  [Year]*100+[Week of Year] > Date.Year(DateTime.LocalNow()) *100+ Date.WeekOfYear(DateTime.LocalNow())  then ""Future Week"" else ""Past Week""),
    #""CurrentDay"" = Table.AddColumn(CurrentWeek, ""Current Day"", each if   Date.From([Date])=Date.From(DateTime.LocalNow()) then ""Current"" else if Date.From( [Date])>=Date.From(DateTime.LocalNow()) then ""Future Day"" else ""Past Day""),
    #""CurrentFiscalYear"" = Table.AddColumn(CurrentDay, ""Current Fiscal Year"", each
        let
            todayMonth = Date.Month(DateTime.LocalNow()),
            todayYear = Date.Year(DateTime.LocalNow()),
            todayFiscalYearStart = if todayMonth >= _FiscalStartMonth then todayYear else todayYear - 1,
            todayFiscalYear = if _FiscalYearBasis = ""End"" then todayFiscalYearStart + 1 else todayFiscalYearStart
        in
            if [FiscalYear] = todayFiscalYear then ""Current""
            else if [FiscalYear] > todayFiscalYear then ""Future Year""
            else ""Past Year""
    ),
    #""CurrentFiscalMonth"" = Table.AddColumn(CurrentFiscalYear, ""Current Fiscal Month"", each [Current Month]),
    #""CurrentFiscalWeek"" = Table.AddColumn(CurrentFiscalMonth, ""Current Fiscal Week"", each [Current Week]),
       ObtenIsoWeek= (Fecha as date) => let
                    #""Removed Other Columns"" = Table.FromRows({{Fecha}},{""FullDateAlternateKey""}),
                    #""Added Custom"" = Table.AddColumn(#""Removed Other Columns"", ""PrimerDiaAño"", each Date.AddDays( #date(Date.Year([FullDateAlternateKey]),1,4) ,-1* Date.DayOfWeek(  #date(Date.Year([FullDateAlternateKey]),1,4),Day.Monday))),
                    #""Added Custom1"" = Table.AddColumn(#""Added Custom"", ""PrimerDiaAnioAA"", each Date.AddDays( #date(Date.Year([FullDateAlternateKey])-1,1,4) ,-1* Date.DayOfWeek(  #date(Date.Year([FullDateAlternateKey])-1,1,4),Day.Monday))),
                    #""Added Custom2"" = Table.AddColumn(#""Added Custom1"", ""PrimerDiaAnioSig"", each Date.AddDays( #date(1+Date.Year([FullDateAlternateKey]),1,4) ,-1* Date.DayOfWeek(  #date(1+Date.Year([FullDateAlternateKey]),1,4),Day.Monday))),
                    #""Changed Type"" = Table.TransformColumnTypes(#""Added Custom2"",{{""PrimerDiaAño"", type date}, {""PrimerDiaAnioAA"", type date}, {""PrimerDiaAnioSig"", type date}}),
                    #""Added Custom3"" = Table.AddColumn(#""Changed Type"", ""AnioNatural"", each Date.Year([FullDateAlternateKey])),
                    #""Added Conditional Column"" = Table.AddColumn(#""Added Custom3"", ""Custom"", each if [FullDateAlternateKey] >= [PrimerDiaAnioSig] then [AnioNatural] +1 else if [FullDateAlternateKey] >= [PrimerDiaAño] then [AnioNatural]  else [AnioNatural] -1 ),
                    #""Sorted Rows"" = Table.Sort(#""Added Conditional Column"",{{""FullDateAlternateKey"", Order.Descending}}),
                    #""Renamed Columns"" = Table.RenameColumns(#""Sorted Rows"",{{""Custom"", ""IsoYear""}}),
                    #""Changed Type1"" = Table.TransformColumnTypes(#""Renamed Columns"",{{""IsoYear"", Int64.Type}}),
                    #""Added Custom4"" = Table.AddColumn(#""Changed Type1"", ""IsoWeek"", each if [FullDateAlternateKey] >= [PrimerDiaAnioSig] then 1 else if [FullDateAlternateKey] >= [PrimerDiaAño] then 1+Number.RoundDown ( Duration.Days ([FullDateAlternateKey]-[PrimerDiaAño])/7 )  else 1+ Number.RoundDown ( Duration.Days ([FullDateAlternateKey]-Date.AddDays( #date(Date.Year([FullDateAlternateKey])-1,1,4) ,-1* Date.DayOfWeek(  #date(Date.Year([FullDateAlternateKey])-1,1,4),Day.Monday)))/7 )),
                        #""Removed Other Columns1"" = Table.SelectColumns(#""Added Custom4"",{""FullDateAlternateKey"", ""IsoYear"", ""IsoWeek""})

                    in
                        #""Removed Other Columns1"" ,
    #""AniadirIsoWeek""=Table.AddColumn( #""CurrentFiscalWeek"",""DatosIso"",each ObtenIsoWeek( Date.From( [Date]))),
    #""Expanded DatosIso"" = Table.ExpandTableColumn(AniadirIsoWeek, ""DatosIso"", {""IsoYear"", ""IsoWeek""}, {""IsoYear"", ""IsoWeek""}),
   #""Added Custom1"" = Table.AddColumn(#""Expanded DatosIso"", ""DayOffset"", each Duration.Days(Date.From([Date])-Date.From(DateTime.LocalNow()))),
    #""Added Custom2"" = Table.AddColumn(#""Added Custom1"", ""YearOffset"", each [Year]- Date.Year(DateTime.LocalNow())),
    #""Added Custom3"" = Table.AddColumn(#""Added Custom2"", ""MonthOffset"", each -1* (  (12 - [Month]) + (-[YearOffset]-1)*12 + Date.Month(DateTime.LocalNow()) )),
    #""Added Custom6"" = Table.AddColumn(#""Added Custom3"", ""QuarterOffset"", each -1* (  (4 - [Quarter]) + (-[YearOffset]-1)*4 + Date.QuarterOfYear(DateTime.LocalNow()) )),
    #""Added IsWorkingDay"" = Table.AddColumn(#""Added Custom6"", ""IsWorkingDay"", each
        [Day of Week] <> 0 and [Day of Week] <> 6
    ),
    #""Added WorkingDayNumber"" =
        let
            grouped = Table.Group(#""Added IsWorkingDay"", {""Year""}, {{""Rows"", each
                let
                    sorted = Table.Sort(_, {{""Date"", Order.Ascending}}),
                    n = Table.RowCount(sorted),
                    flags = Table.Column(sorted, ""IsWorkingDay""),
                    running = List.Generate(
                        () => [i = 0, acc = 0],
                        each [i] < n,
                        each [i = [i] + 1, acc = [acc] + (if flags{[i]} then 1 else 0)],
                        each [acc] + (if flags{[i]} then 1 else 0)
                    )
                in
                    Table.FromColumns(Table.ToColumns(sorted) & {running}, Table.ColumnNames(sorted) & {""WorkingDayNumber""})
            , type table}}),
            combined = Table.Sort(Table.Combine(grouped[Rows]), {{""Date"", Order.Ascending}})
        in
            combined,
    #""Changed Type2"" = Table.TransformColumnTypes(#""Added WorkingDayNumber"",{{""DayOffset"", Int64.Type}, {""IsoWeek"", Int64.Type}, {""IsoYear"", Int64.Type}, {""YearOffset"", Int64.Type},{""QuarterOffset"", Int64.Type},  {""MonthOffset"", Int64.Type}, {""Current Year"", type text}, {""Current Month"", type text}, {""Current Week"", type text}, {""Current Day"", type text}, {""Current Fiscal Year"", type text}, {""Current Fiscal Month"", type text}, {""Current Fiscal Week"", type text}, {""IsWorkingDay"", type logical}, {""WorkingDayNumber"", Int64.Type}})

in
   #""Changed Type2""
";
partition.Mode=ModeType.Import ;
tab.Partitions.ConvertToPowerQuery();


if (tab.Columns.Count==0)
{
var col=tab.AddDataColumn("Date","Date");
 col=tab.AddDataColumn("FiscalDate","FiscalDate");
col=tab.AddDataColumn("Year","Year");
col=tab.AddDataColumn("Month","Month");
col=tab.AddDataColumn("Month Name","Month Name");
col=tab.AddDataColumn("MonthKey","MonthKey");
col=tab.AddDataColumn("Month Name Short","Month Name Short");
col=tab.AddDataColumn("Month Name Complete","Month Name Complete");
col=tab.AddDataColumn("Month Name Short Complete","Month Name Short Complete");
col=tab.AddDataColumn("Quarter","Quarter");
col=tab.AddDataColumn("QuarterCode","QuarterCode");
col=tab.AddDataColumn("Week of Year","Week of Year");
col=tab.AddDataColumn("Day","Day");
col=tab.AddDataColumn("Day Of Week","Day of Week");
col=tab.AddDataColumn("Day of Year","Day of Year");
col=tab.AddDataColumn("Day Name","Day Name");
col=tab.AddDataColumn("Fiscal Week of Year","Fiscal Week of Year");
col=tab.AddDataColumn("FiscalYear","FiscalYear");
col=tab.AddDataColumn("FiscalQuarter","FiscalQuarter");
col=tab.AddDataColumn("FiscalQuarterCode","FiscalQuarterCode");
col=tab.AddDataColumn("Current Year","Current Year");
col=tab.AddDataColumn("Current Month","Current Month");
col=tab.AddDataColumn("Current Week","Current Week");
col=tab.AddDataColumn("Current Day","Current Day");
col=tab.AddDataColumn("Current Fiscal Year","Current Fiscal Year");
col=tab.AddDataColumn("Current Fiscal Month","Current Fiscal Month");
col=tab.AddDataColumn("Current Fiscal Week","Current Fiscal Week");
col=tab.AddDataColumn("ISOYear","IsoYear");
col=tab.AddDataColumn("ISOWeek","IsoWeek");
col=tab.AddDataColumn("DayOffset","DayOffset");
col=tab.AddDataColumn("MonthOffset","MonthOffset");
col=tab.AddDataColumn("YearOffset","YearOffset");
col=tab.AddDataColumn("QuarterOffset","QuarterOffset");
col=tab.AddDataColumn("idFecha","idFecha");
col=tab.AddDataColumn("IsWorkingDay","IsWorkingDay");
col=tab.AddDataColumn("WorkingDayNumber","WorkingDayNumber");
}
foreach(var col in tab.Columns)
{
    col.IsHidden=false;
    col.SummarizeBy = AggregateFunction.None;

}

// Carpetas: taxonomía única de 5 grupos (en vez de la mezcla ad hoc anterior,
// que dejaba QuarterCode fuera de la carpeta de claves junto a idFecha/MonthKey).
var carpetaDescriptivos = "Atributos descriptivos";
var carpetaOrdinales = "Ordinales";
var carpetaClaves = "Claves";
var carpetaOffsets = @"Posiciones relativas\Offsets";
var carpetaEstado = @"Posiciones relativas\Estado";
var carpetaLaborables = "Días laborables";

var columnasDescriptivos = new [] {"FiscalDate","Year","Month Name","Month Name Short","Month Name Complete","Month Name Short Complete","Day Name","FiscalYear","IsoYear"};
var columnasOrdinales = new [] {"Month","Quarter","Week of Year","Day","Day of Week","Day of Year","Fiscal Week of Year","FiscalQuarter","IsoWeek"};
var columnasClaves = new [] {"idFecha","MonthKey","QuarterCode","FiscalQuarterCode"};
var columnasOffsets = new [] {"DayOffset","MonthOffset","YearOffset","QuarterOffset"};
var columnasEstado = new [] {"Current Year","Current Month","Current Week","Current Day","Current Fiscal Year","Current Fiscal Month","Current Fiscal Week"};
var columnasLaborables = new [] {"IsWorkingDay","WorkingDayNumber"};

foreach (var n in columnasDescriptivos) tab.Columns[n].DisplayFolder = carpetaDescriptivos;
foreach (var n in columnasOrdinales) tab.Columns[n].DisplayFolder = carpetaOrdinales;
foreach (var n in columnasClaves) tab.Columns[n].DisplayFolder = carpetaClaves;
foreach (var n in columnasOffsets) tab.Columns[n].DisplayFolder = carpetaOffsets;
foreach (var n in columnasEstado) tab.Columns[n].DisplayFolder = carpetaEstado;
foreach (var n in columnasLaborables) tab.Columns[n].DisplayFolder = carpetaLaborables;

tab.DataCategory= "Time";
var fecha=tab.Columns["Date"];
fecha.IsHidden=true;
fecha.IsKey=true;

var colyear= tab.Columns["Year"];
var colMonth = tab.Columns["Month Name"];
if (colMonth.SortByColumn == null )
{
    colMonth.SortByColumn=tab.Columns["Month"];
}
 colMonth = tab.Columns["Month Name Short"];
if (colMonth.SortByColumn == null )
{
    colMonth.SortByColumn=tab.Columns["Month"];
}
colMonth = tab.Columns["Month Name Complete"];
if (colMonth.SortByColumn == null )
{
    colMonth.SortByColumn=tab.Columns["MonthKey"];
}
colMonth = tab.Columns["Month Name Short Complete"];
if (colMonth.SortByColumn == null )
{
    colMonth.SortByColumn=tab.Columns["MonthKey"];
}
var colDayName = tab.Columns["Day Name"];
if (colDayName.SortByColumn == null )
{
    colDayName.SortByColumn=tab.Columns["Day of Week"];
}

var colDate = tab.Columns["Date"];
var crearjerarquiaincial="no";
if (tab.Hierarchies.Count()==0 )
{    tab.AddHierarchy("Calendar");
    crearjerarquiaincial="si";
}

var Hier =tab.Hierarchies[0];

if (crearjerarquiaincial == "si")
 {
    Hier.AddLevel(colyear,"Year");
    Hier.AddLevel(colMonth,"Month");
    Hier.AddLevel(colDate,"Date");
}
var ExistH=tab.Hierarchies[0];
ExistH=null;
foreach(var h in tab.Hierarchies)
{
    if (h.Name=="Fiscal")
          CrearFiscal="no";
}




/* si lo piden creamos la jerarquía fiscal */
if (CrearFiscal=="si")
{
    Hier= tab.AddHierarchy("Fiscal");
    colyear= tab.Columns["FiscalYear"];
    Hier.AddLevel(colyear,"Year");
    Hier.AddLevel(colMonth,"Month");
    Hier.AddLevel(colDate,"Date");
}
foreach(var h in tab.Hierarchies)
{
    if (h.Name=="Calendar Week")
         CrearSemana="no";
}



/* si lo piden creamos la jerarquía semana */
if (CrearSemana=="si")
{
    Hier= tab.AddHierarchy("Calendar Week");
    colyear= tab.Columns["Year"];
    Hier.AddLevel(colyear,"Year");
    var colWeek= tab.Columns["Week of Year"];
    Hier.AddLevel(colWeek,"Week of Year");
    Hier.AddLevel(colDate,"Date");
}

foreach(var h in tab.Hierarchies)
{
    if (h.Name=="Fiscal Week")
         CrearSemanaFiscal="no";
}


/* si lo piden creamos la jerarquía semana */
if (CrearSemanaFiscal=="si")
{
    Hier= tab.AddHierarchy("Fiscal Week");
    colyear= tab.Columns["FiscalYear"];
    Hier.AddLevel(colyear,"Fiscal Year");
    var colWeek= tab.Columns["Fiscal Week of Year"];
    Hier.AddLevel(colWeek,"Fiscal Week of Year");
    Hier.AddLevel(colDate,"Date");
}

foreach(var h in tab.Hierarchies)
{
    if (h.Name=="Iso Week")
        CrearIso="no";
}
if( CrearIso=="si")
{
        Hier= tab.AddHierarchy("Iso Week");
        colyear= tab.Columns["IsoYear"];
        Hier.AddLevel(colyear,"Iso Year");
        var colWeek= tab.Columns["IsoWeek"];
        Hier.AddLevel(colWeek,"IsoWeek");
        Hier.AddLevel(colDate,"Date");
}


var ToColumnstr=ToColumn.Split(',');

foreach(var s in ToColumnstr)
{

    if (s!="");
    {
        // s.Output();
       try {
        var FromColumn = Model.Tables[ToTable].Columns[s];


        foreach(var rel in Model.Relationships)
        {
             if (rel.FromColumn.Name==FromColumn.Name && rel.FromColumn.Table ==FromColumn.Table &&
                 rel.ToColumn.Name==colDate.Name && rel.ToColumn.Table==colDate.Table)
                  {
                      ToTable="";
                      ToColumn="";
                  }
        }


        if (ToTable!="" && ToColumn!="")

        {
            /* le llamo from porque generalmente pbi está haciendo las relaciones en la direccion * ---> 1 */
            var rel=Model.AddRelationship();
            rel.FromColumn=FromColumn;
            rel.ToColumn=colDate;
        }
    }
    catch (Exception ex)
    {
        // no hago nada si no existe la tabla con la que enganchar
    }
}

}

tab2.Delete();
var measure= @"
 VAR _min =MIN ( '" + tname + @"'[Date] )
    VAR _max = MAX ( '" + tname + @"'[Date] )
    VAR _todos =SUMMARIZE('" + tname + @"','" + tname + @"'[Date],'" + tname + @"'[DayOffset],""sig"" ,'" + tname + @"'[DayOffset]+1, ""ant"",'" + tname + @"'[DayOffset]-1)
    var _txt1 =CONCATENATEX(_todos,'" + tname + @"'[Date] &  "" | "" & '" + tname + @"'[DayOffset] & "" | "" &[sig] & "" | "" &[ant],"","")
    var _enri= ADDCOLUMNS(_todos, ""tieneAnterior"", COUNTX( var _an=[ant] return filter(_todos,'" + tname + @"'[DayOffset]=_an),1),
                                  ""tienesiguiente"", COUNTX( var _an=[sig] return filter(_todos,'" + tname + @"'[DayOffset]=_an),1) )
    var _enri2=  ADDCOLUMNS(_enri,""concatenar"",
                IF (
                    ISBLANK ( [tieneanterior] ) && NOT ISBLANK ( [tienesiguiente] ),
                    ""-"",
                    IF ( ISBLANK ( [tienesiguiente] ), "","" )
                ))
    VAR _devolver =
        CONCATENATEX (
            FILTER ( _enri2, NOT ISBLANK ( [concatenar] ) ),
            '" + tname + @"'[Date] & [concatenar],"""",'" + tname + @"'[Date])
    var _txt2 =CONCATENATEX(_enri2,'" + tname + @"'[Date] &  "" | "" & [concatenar] ,"","",'" + tname + @"'[Date])
    return _devolver";

tab.AddMeasure(tname + "_selection",measure);

/*
var type = "calculate";
var database = Model.Database.Name;
var table = tab.Name;
var tmsl = "{ \"refresh\": { \"type\": \"%type%\", \"objects\": [ { \"database\": \"%db%\", \"table\": \"%table%\" } ] } }"
    .Replace("%type%", type)
    .Replace("%db%", database)
    .Replace("%table%", table);

ExecuteCommand(tmsl);
*/
