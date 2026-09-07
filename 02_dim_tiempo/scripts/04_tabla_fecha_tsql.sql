/* ============================================================================
   Tabla de fechas — T-SQL para Microsoft Fabric Data Warehouse (o Lakehouse SQL
   endpoint como origen de lectura; el CREATE TABLE AS SELECT solo aplica en
   Warehouse). v2.

   Notas de diseño frente a la versión Power Query:
   - La columna [Date] se genera como DATE (no DATETIME). Eso elimina de raíz la
     clase de bug que tuvo "Current Day" en M: en T-SQL, comparar DATE = DATE (o
     DATE contra CAST(GETDATE() AS DATE)) nunca mezcla tipos con hora.
   - DayOffset/MonthOffset/QuarterOffset usan DATEDIFF, que cuenta límites de
     calendario cruzados, no restas de tiempo — así que no sufren el truncamiento
     que tenía el DayOffset original en M (ver 01_powerquery_tabla_fecha.pq).
   - IsoWeek usa DATEPART(ISO_WEEK, ...), que ya implementa ISO 8601 de forma
     nativa desde SQL Server 2012 — no hace falta la función auxiliar
     "ObtenIsoWeek" que sí hizo falta en M.
   - "Current Week" compara Year*100+WeekOfYear consistentemente (el bug de la
     versión M comparaba Month contra WeekOfYear — ver el artículo).
   - FiscalYear/FiscalQuarter se calculan directamente desde Year/Month y
     @FiscalStartMonth (no desplazando la fecha con DATEADD), con
     @FiscalYearBasis decidiendo explícitamente si el año fiscal se nombra por
     el año en que arranca o por el año en que termina — ver el artículo
     (auditoría de reusabilidad, gap "calendario fiscal explícito").
   - IsWorkingDay marca de lunes a viernes; no contempla festivos (en España
     hay nacionales, autonómicos y locales, así que esa lógica se resuelve
     aparte, cruzando contra tu propia tabla de festivos donde la necesites,
     no dentro de esta dimensión). WorkingDayNumber es un contador de días
     laborables acumulado dentro de cada año natural, calculado con una
     función de ventana (mucho más simple que el List.Generate que hace falta
     en M para el mismo resultado).

   Ajusta @StartYear / @EndYear / @FiscalStartMonth / @FiscalYearBasis y el
   nombre de esquema/tabla a tu caso.
   ========================================================================== */

SET DATEFIRST 7; -- domingo = 1er día de la semana, para alinear DayOfWeek con
                  -- el "0 = domingo" por defecto de Power Query (Date.DayOfWeek)

DECLARE @StartYear         INT          = 2019;
DECLARE @EndYear           INT          = 2025;
DECLARE @FiscalStartMonth  INT          = 6;       -- 6 = el año fiscal arranca en junio
DECLARE @FiscalYearBasis   VARCHAR(5)   = 'End';   -- 'Start' o 'End' — ver cabecera

DECLARE @StartDate DATE = DATEFROMPARTS(@StartYear, 1, 1);
DECLARE @EndDateEx DATE = DATEFROMPARTS(@EndYear + 1, 1, 1); -- exclusivo

DECLARE @TodayFiscalYearStart INT = CASE WHEN MONTH(GETDATE()) >= @FiscalStartMonth THEN YEAR(GETDATE()) ELSE YEAR(GETDATE()) - 1 END;
DECLARE @TodayFiscalYear      INT = CASE WHEN @FiscalYearBasis = 'End' THEN @TodayFiscalYearStart + 1 ELSE @TodayFiscalYearStart END;

IF OBJECT_ID('dbo.DimFecha') IS NOT NULL
    DROP TABLE dbo.DimFecha;

WITH E1(N) AS ( -- 10 filas
    SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1
    UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1
),
E2(N) AS (SELECT 1 FROM E1 a CROSS JOIN E1 b),        -- 100 filas
E4(N) AS (SELECT 1 FROM E2 a CROSS JOIN E2 b),        -- 10.000 filas
Tally(N) AS (
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 FROM E4
),
Dates AS (
    SELECT DATEADD(DAY, N, @StartDate) AS [Date]
    FROM Tally
    WHERE N < DATEDIFF(DAY, @StartDate, @EndDateEx)
),
Base AS (
    SELECT
        d.[Date],
        DATEADD(MONTH, -@FiscalStartMonth, d.[Date])                          AS FiscalDate,
        YEAR(d.[Date])                                                        AS [Year],
        MONTH(d.[Date])                                                       AS [Month],
        DATENAME(MONTH, d.[Date])                                             AS [Month Name],
        DATEPART(QUARTER, d.[Date])                                           AS Quarter,
        DATEPART(WEEK, d.[Date])                                              AS [Week of Year],
        DAY(d.[Date])                                                         AS [Day],
        DATEPART(WEEKDAY, d.[Date]) - 1                                       AS [Day of Week], -- 0 = domingo
        DATEPART(DAYOFYEAR, d.[Date])                                         AS [Day of Year],
        DATENAME(WEEKDAY, d.[Date])                                           AS [Day Name],
        DATEPART(ISO_WEEK, d.[Date])                                          AS IsoWeek,
        CASE
            WHEN DATEPART(ISO_WEEK, d.[Date]) >= 52 AND MONTH(d.[Date]) = 1  THEN YEAR(d.[Date]) - 1
            WHEN DATEPART(ISO_WEEK, d.[Date]) = 1  AND MONTH(d.[Date]) = 12 THEN YEAR(d.[Date]) + 1
            ELSE YEAR(d.[Date])
        END                                                                   AS IsoYear
    FROM Dates d
),
Fiscal AS (
    SELECT
        b.*,
        CASE WHEN @FiscalYearBasis = 'End'
             THEN (CASE WHEN b.[Month] >= @FiscalStartMonth THEN b.[Year] ELSE b.[Year] - 1 END) + 1
             ELSE (CASE WHEN b.[Month] >= @FiscalStartMonth THEN b.[Year] ELSE b.[Year] - 1 END)
        END                                                                   AS FiscalYear,
        ((((b.[Month] - @FiscalStartMonth) % 12) + 12) % 12) / 3 + 1          AS FiscalQuarter
    FROM Base b
),
Enriched AS (
    SELECT
        f.*,
        LEFT(f.[Month Name], 3)                                               AS [Month Name Short],
        f.[Month Name] + ' ' + CAST(f.[Year] AS VARCHAR(4))                   AS [Month Name Complete],
        LEFT(f.[Month Name], 3) + ' ' + RIGHT(CAST(f.[Year] AS VARCHAR(4)), 2) AS [Month Name Short Complete],
        f.[Year] * 10000 + f.[Month] * 100 + f.[Day]                          AS idFecha,
        f.[Year] * 100 + f.[Month]                                            AS MonthKey,
        f.[Year] * 100 + f.Quarter                                            AS QuarterCode,
        f.FiscalYear * 100 + f.FiscalQuarter                                  AS FiscalQuarterCode,
        DATEPART(WEEK, f.FiscalDate)                                          AS [Fiscal Week of Year],
        DATEDIFF(DAY,   CAST(GETDATE() AS DATE), f.[Date])                    AS DayOffset,
        f.[Year] - YEAR(GETDATE())                                            AS YearOffset,
        DATEDIFF(MONTH,   GETDATE(), f.[Date])                                AS MonthOffset,
        DATEDIFF(QUARTER, GETDATE(), f.[Date])                                AS QuarterOffset
    FROM Fiscal f
),
WithCurrent AS (
    SELECT
        e.*,
        CASE WHEN e.[Year] = YEAR(GETDATE()) THEN 'Current'
             WHEN e.[Year] > YEAR(GETDATE()) THEN 'Future Year' ELSE 'Past Year' END AS [Current Year],
        CASE WHEN e.MonthKey = YEAR(GETDATE())*100 + MONTH(GETDATE()) THEN 'Current'
             WHEN e.MonthKey > YEAR(GETDATE())*100 + MONTH(GETDATE()) THEN 'Future Month' ELSE 'Past Month' END AS [Current Month],
        CASE WHEN e.[Year]*100 + e.[Week of Year] = YEAR(GETDATE())*100 + DATEPART(WEEK, GETDATE()) THEN 'Current'
             WHEN e.[Year]*100 + e.[Week of Year] > YEAR(GETDATE())*100 + DATEPART(WEEK, GETDATE()) THEN 'Future Week' ELSE 'Past Week' END AS [Current Week],
        CASE WHEN e.[Date] = CAST(GETDATE() AS DATE) THEN 'Current'
             WHEN e.[Date] >  CAST(GETDATE() AS DATE) THEN 'Future Day' ELSE 'Past Day' END AS [Current Day],
        CASE WHEN e.FiscalYear = @TodayFiscalYear THEN 'Current'
             WHEN e.FiscalYear > @TodayFiscalYear THEN 'Future Year' ELSE 'Past Year' END AS [Current Fiscal Year]
    FROM Enriched e
),
WithWorking AS (
    SELECT
        w.*,
        CASE WHEN w.[Day of Week] NOT IN (0, 6)
             THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END                      AS IsWorkingDay
    FROM WithCurrent w
),
WithWorkingNumber AS (
    SELECT
        ww.*,
        SUM(CASE WHEN ww.IsWorkingDay = 1 THEN 1 ELSE 0 END)
            OVER (PARTITION BY ww.[Year] ORDER BY ww.[Date] ROWS UNBOUNDED PRECEDING) AS WorkingDayNumber
    FROM WithWorking ww
)
-- CTAS (CREATE TABLE AS SELECT): es el patrón soportado por Fabric Warehouse
-- para materializar una consulta como tabla; Fabric gestiona la distribución y
-- el almacenamiento por ti, no hace falta WITH DISTRIBUTION/INDEX como en
-- Synapse dedicado. (SELECT ... INTO no está soportado en Fabric Warehouse.)
CREATE TABLE dbo.DimFecha
AS
SELECT
    n.*,
    n.[Current Month] AS [Current Fiscal Month],   -- mismo alias que la versión M
    n.[Current Week]  AS [Current Fiscal Week]     -- mismo alias que la versión M
FROM WithWorkingNumber n;

-- Sanity checks rápidos
-- SELECT COUNT(*) AS Filas, MIN([Date]) AS Min_Fecha, MAX([Date]) AS Max_Fecha FROM dbo.DimFecha;
-- SELECT [Date],[Current Day],[Current Week] FROM dbo.DimFecha WHERE [Date] = CAST(GETDATE() AS DATE);
-- SELECT [Date],[IsWorkingDay],[WorkingDayNumber] FROM dbo.DimFecha WHERE [Year] = YEAR(GETDATE()) ORDER BY [Date];
