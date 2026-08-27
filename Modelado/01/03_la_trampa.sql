-- ============================================================
-- LA TRAMPA — el número que sorprende en la demo
-- ============================================================
-- Escenario real: al modelo plano le piden UNA columna más:
-- "quiero ver también el histórico de territorio del vendedor".
-- dbo.Dim_Vendedor_Historial tiene varias filas por vendedor
-- (una por cada cambio de territorio a lo largo de su carrera).
--
-- Como en el modelo plano todo vive en una sola tabla, ese dato
-- solo se puede añadir haciendo JOIN directamente sobre las líneas
-- de venta. Resultado: las líneas se duplican, y con ellas la
-- venta total. Nadie ha vendido más — el modelo simplemente no
-- tiene dónde poner un dato "uno a muchos" sin repetir el hecho.
--
-- En el modelo en estrella este problema no existe: el histórico
-- de territorio sería una tabla más relacionada con Dim_Vendedor,
-- nunca con Fact_Ventas. La estrella obliga a decidir el grano;
-- la tabla plana no.
-- ============================================================

SELECT
    'A. Modelo plano, sin histórico (el número real)'   AS Version,
    COUNT(*)          AS Filas,
    SUM(LineTotal)    AS VentaTotal
FROM dbo.Ventas_Plano

UNION ALL

SELECT
    'B. Modelo plano + histórico de territorio del vendedor (mismo tipo de JOIN de siempre)' AS Version,
    COUNT(*)                AS Filas,
    SUM(v.LineTotal)         AS VentaTotal
FROM dbo.Ventas_Plano v
JOIN dbo.Dim_Vendedor_Historial sth ON sth.VendedorKey = v.VendedorID;

-- ------------------------------------------------------------
-- Apunta estos dos números para la demo:
--   Filas   A vs B   -> deberían ser iguales, no lo son
--   Venta   A vs B   -> deberían ser iguales, no lo son
-- La diferencia es exactamente el "número que sorprende incluso
-- a quien lleva diez años" de la planta alta del artículo.
-- ------------------------------------------------------------
