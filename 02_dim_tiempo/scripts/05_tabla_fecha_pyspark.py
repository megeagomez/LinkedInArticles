# =============================================================================
# Tabla de fechas — PySpark para un notebook de Microsoft Fabric (Lakehouse). v2
# Pensado para pegar en un notebook Fabric; cada bloque "# CELL" es una celda.
#
# Notas de diseño frente a la versión Power Query:
# - [Date] se genera como DateType puro (sequence de tipo date), no timestamp.
#   Igual que en la versión T-SQL, esto evita de raíz la clase de bug que tuvo
#   "Current Day" en M (mezclar date y datetime en una comparación de igualdad).
# - DayOffset/MonthOffset/QuarterOffset se calculan con aritmética entera sobre
#   Year/Month/Quarter (igual que el DATEDIFF de la versión T-SQL), no restando
#   fechas con hora — así que tampoco heredan el truncamiento que tenía la
#   versión M original.
# - IsoWeek usa F.weekofyear(), que en Spark ya es ISO 8601 nativo (Monday-start,
#   semana 1 = la que contiene el primer jueves del año) — no hace falta la
#   función auxiliar "ObtenIsoWeek" que sí hizo falta en M.
# - "Week of Year" (estilo Power Query: semana empieza en domingo, semana 1 =
#   la que contiene el 1 de enero) se aproxima con date_format(...,'w'), que
#   depende del locale por defecto de la JVM (normalmente en-US en Fabric, que
#   coincide con la convención de Power Query). Si tu clúster usa otro locale
#   por defecto, verifica esta columna contra la versión M/T-SQL antes de
#   confiar en ella cerca de fin de año.
# - "Current Week" compara (Year, Week of Year) de forma consistente, evitando
#   el bug de la versión M original (que comparaba Month contra WeekOfYear).
# - FiscalYear/FiscalQuarter se calculan directamente desde Year/Month y
#   fiscal_start_month (no desplazando la fecha con add_months), con
#   fiscal_year_basis decidiendo explícitamente si el año fiscal se nombra por
#   el año en que arranca o por el año en que termina — ver el artículo
#   (auditoría de reusabilidad, gap "calendario fiscal explícito").
# - IsWorkingDay marca de lunes a viernes; no contempla festivos (en España
#   hay nacionales, autonómicos y locales, así que esa lógica se resuelve
#   aparte, cruzando contra tu propia tabla de festivos donde la necesites,
#   no dentro de esta dimensión). WorkingDayNumber es un contador de días
#   laborables acumulado dentro de cada año natural, calculado con una
#   función de ventana — igual de simple que en T-SQL, mucho más simple que
#   el List.Generate que hace falta en M.
# =============================================================================

# CELL 1 — parámetros
start_year = 2019
end_year = 2025
fiscal_start_month = 6      # el año fiscal arranca en junio
fiscal_year_basis = "End"   # "Start" o "End" — ver cabecera

# CELL 2 — imports y generación del rango de fechas
from datetime import date
from pyspark.sql import functions as F
from pyspark.sql.window import Window

df = spark.sql(f"""
    SELECT explode(sequence(
        to_date('{start_year}-01-01'),
        to_date('{end_year}-12-31'),
        interval 1 day
    )) AS Date
""")

# CELL 3 — columnas de calendario base
df = (
    df
    .withColumn("FiscalDate", F.add_months(F.col("Date"), -fiscal_start_month))
    .withColumn("Year", F.year("Date"))
    .withColumn("Month", F.month("Date"))
    .withColumn("Month Name", F.date_format("Date", "MMMM"))
    .withColumn("Month Name Short", F.substring(F.col("Month Name"), 1, 3))
    .withColumn("Month Name Complete", F.concat_ws(" ", F.col("Month Name"), F.col("Year")))
    .withColumn(
        "Month Name Short Complete",
        F.concat_ws(" ", F.col("Month Name Short"), F.lpad((F.col("Year") % 100).cast("string"), 2, "0")),
    )
    .withColumn("Quarter", F.quarter("Date"))
    .withColumn("Week of Year", F.date_format("Date", "w").cast("int"))
    .withColumn("Day", F.dayofmonth("Date"))
    .withColumn("Day of Week", F.dayofweek("Date") - 1)  # 0 = domingo, como Date.DayOfWeek en M
    .withColumn("Day of Year", F.dayofyear("Date"))
    .withColumn("Day Name", F.date_format("Date", "EEEE"))
    .withColumn("IsoWeek", F.weekofyear("Date"))
    .withColumn(
        "IsoYear",
        F.when((F.col("IsoWeek") >= 52) & (F.col("Month") == 1), F.col("Year") - 1)
         .when((F.col("IsoWeek") == 1) & (F.col("Month") == 12), F.col("Year") + 1)
         .otherwise(F.col("Year")),
    )
)

# CELL 4 — año/trimestre fiscal explícitos (ver cabecera)
df = (
    df
    .withColumn(
        "FiscalYearStart",
        F.when(F.col("Month") >= fiscal_start_month, F.col("Year")).otherwise(F.col("Year") - 1),
    )
    .withColumn(
        "FiscalYear",
        F.col("FiscalYearStart") + 1 if fiscal_year_basis == "End" else F.col("FiscalYearStart"),
    )
    .withColumn(
        "FiscalQuarter",
        F.floor(F.pmod(F.col("Month") - fiscal_start_month, F.lit(12)) / 3).cast("int") + 1,
    )
    .withColumn("FiscalQuarterCode", F.col("FiscalYear") * 100 + F.col("FiscalQuarter"))
    .drop("FiscalYearStart")
)

# CELL 5 — claves y offsets
df = (
    df
    .withColumn("idFecha", F.col("Year") * 10000 + F.col("Month") * 100 + F.col("Day"))
    .withColumn("MonthKey", F.col("Year") * 100 + F.col("Month"))
    .withColumn("QuarterCode", F.col("Year") * 100 + F.col("Quarter"))
    .withColumn("Fiscal Week of Year", F.date_format("FiscalDate", "w").cast("int"))
    .withColumn("DayOffset", F.datediff(F.col("Date"), F.current_date()))
    .withColumn("YearOffset", F.col("Year") - F.year(F.current_date()))
    .withColumn(
        "MonthOffset",
        (F.col("Year") - F.year(F.current_date())) * 12 + (F.col("Month") - F.month(F.current_date())),
    )
    .withColumn(
        "QuarterOffset",
        (F.col("Year") - F.year(F.current_date())) * 4 + (F.col("Quarter") - F.quarter(F.current_date())),
    )
)

# CELL 6 — banderas "Current …" (comparación siempre date-vs-date, sin horas)
today = F.current_date()

_today = date.today()
_today_fiscal_year_start = _today.year if _today.month >= fiscal_start_month else _today.year - 1
today_fiscal_year = _today_fiscal_year_start + 1 if fiscal_year_basis == "End" else _today_fiscal_year_start

df = (
    df
    .withColumn(
        "Current Year",
        F.when(F.col("Year") == F.year(today), "Current")
         .when(F.col("Year") > F.year(today), "Future Year")
         .otherwise("Past Year"),
    )
    .withColumn(
        "Current Month",
        F.when(F.col("MonthKey") == F.year(today) * 100 + F.month(today), "Current")
         .when(F.col("MonthKey") > F.year(today) * 100 + F.month(today), "Future Month")
         .otherwise("Past Month"),
    )
    .withColumn(
        "Current Week",
        F.when(
            F.col("Year") * 100 + F.col("Week of Year") == F.year(today) * 100 + F.date_format(today, "w").cast("int"),
            "Current",
        )
        .when(
            F.col("Year") * 100 + F.col("Week of Year") > F.year(today) * 100 + F.date_format(today, "w").cast("int"),
            "Future Week",
        )
        .otherwise("Past Week"),
    )
    .withColumn(
        "Current Day",
        F.when(F.col("Date") == today, "Current")
         .when(F.col("Date") > today, "Future Day")
         .otherwise("Past Day"),
    )
    .withColumn(
        "Current Fiscal Year",
        F.when(F.col("FiscalYear") == F.lit(today_fiscal_year), "Current")
         .when(F.col("FiscalYear") > F.lit(today_fiscal_year), "Future Year")
         .otherwise("Past Year"),
    )
    .withColumn("Current Fiscal Month", F.col("Current Month"))   # mismo alias que la versión M
    .withColumn("Current Fiscal Week", F.col("Current Week"))     # mismo alias que la versión M
)

# CELL 7 — días laborables: IsWorkingDay + WorkingDayNumber (contador por año)
df = df.withColumn("IsWorkingDay", ~F.col("Day of Week").isin(0, 6))

_yearWindow = Window.partitionBy("Year").orderBy("Date").rowsBetween(Window.unboundedPreceding, 0)
df = df.withColumn(
    "WorkingDayNumber",
    F.sum(F.when(F.col("IsWorkingDay"), 1).otherwise(0)).over(_yearWindow),
)

# CELL 8 — escritura como tabla Delta en el Lakehouse
(
    df.write
      .format("delta")
      .mode("overwrite")
      .option("overwriteSchema", "true")
      .saveAsTable("DimFecha")
)

# CELL 9 — sanity checks rápidos
# display(df.filter(F.col("Date") == F.current_date()).select("Date", "Current Day", "Current Week"))
# print(df.count(), df.select(F.min("Date"), F.max("Date")).first())
# display(df.filter(F.col("Year") == date.today().year).select("Date", "IsWorkingDay", "WorkingDayNumber").orderBy("Date"))
