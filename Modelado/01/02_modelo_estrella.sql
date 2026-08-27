-- ============================================================
-- MODELO EN ESTRELLA — misma pregunta de negocio, mismo grano,
-- hechos y dimensiones separados.
-- ============================================================
-- Base de datos: AdventureWorks2019 / AdventureWorks2022 (OLTP)
-- ============================================================

-- ---------------------------------------------
-- DIM_FECHA (calendario continuo, como cualquier
-- tabla de fechas real de un modelo semántico)
-- ---------------------------------------------
IF OBJECT_ID('dbo.Dim_Fecha', 'U') IS NOT NULL DROP TABLE dbo.Dim_Fecha;

;WITH Fechas AS (
    SELECT CAST('2011-01-01' AS DATE) AS Fecha
    UNION ALL
    SELECT DATEADD(DAY, 1, Fecha) FROM Fechas WHERE Fecha < '2014-12-31'
)
SELECT
    CONVERT(INT, FORMAT(Fecha, 'yyyyMMdd'))  AS FechaKey,
    Fecha,
    YEAR(Fecha)                              AS Anio,
    DATEPART(QUARTER, Fecha)                 AS Trimestre,
    MONTH(Fecha)                             AS Mes,
    DATENAME(MONTH, Fecha)                   AS NombreMes,
    DATEPART(WEEK, Fecha)                    AS Semana,
    DATENAME(WEEKDAY, Fecha)                 AS DiaSemana
INTO dbo.Dim_Fecha
FROM Fechas
OPTION (MAXRECURSION 0);

-- ---------------------------------------------
-- DIM_PRODUCTO
-- ---------------------------------------------
IF OBJECT_ID('dbo.Dim_Producto', 'U') IS NOT NULL DROP TABLE dbo.Dim_Producto;

SELECT
    pr.ProductID                             AS ProductoKey,
    pr.Name                                  AS Producto,
    pr.Color,
    pr.StandardCost,
    pr.ListPrice,
    psc.Name                                 AS Subcategoria,
    pc.Name                                  AS Categoria
INTO dbo.Dim_Producto
FROM Production.Product pr
LEFT JOIN Production.ProductSubcategory psc ON psc.ProductSubcategoryID = pr.ProductSubcategoryID
LEFT JOIN Production.ProductCategory    pc  ON pc.ProductCategoryID = psc.ProductCategoryID;

-- ---------------------------------------------
-- DIM_CLIENTE
-- ---------------------------------------------
IF OBJECT_ID('dbo.Dim_Cliente', 'U') IS NOT NULL DROP TABLE dbo.Dim_Cliente;

SELECT
    c.CustomerID                             AS ClienteKey,
    p.FirstName + ' ' + p.LastName           AS NombreCliente
INTO dbo.Dim_Cliente
FROM Sales.Customer c
LEFT JOIN Person.Person p ON p.BusinessEntityID = c.PersonID;

-- ---------------------------------------------
-- DIM_TERRITORIO
-- ---------------------------------------------
IF OBJECT_ID('dbo.Dim_Territorio', 'U') IS NOT NULL DROP TABLE dbo.Dim_Territorio;

SELECT
    st.TerritoryID                           AS TerritorioKey,
    st.Name                                  AS Territorio,
    st.CountryRegionCode
INTO dbo.Dim_Territorio
FROM Sales.SalesTerritory st;

-- ---------------------------------------------
-- DIM_VENDEDOR
-- ---------------------------------------------
IF OBJECT_ID('dbo.Dim_Vendedor', 'U') IS NOT NULL DROP TABLE dbo.Dim_Vendedor;

SELECT
    sp.BusinessEntityID                      AS VendedorKey,
    pv.FirstName + ' ' + pv.LastName         AS NombreVendedor
INTO dbo.Dim_Vendedor
FROM Sales.SalesPerson sp
LEFT JOIN Person.Person pv ON pv.BusinessEntityID = sp.BusinessEntityID;

-- ---------------------------------------------
-- FACT_VENTAS (mismo grano que Ventas_Plano: una fila por línea de pedido)
-- ---------------------------------------------
IF OBJECT_ID('dbo.Fact_Ventas', 'U') IS NOT NULL DROP TABLE dbo.Fact_Ventas;

SELECT
    sod.SalesOrderID,
    sod.SalesOrderDetailID,
    CONVERT(INT, FORMAT(soh.OrderDate, 'yyyyMMdd'))   AS FechaKey,
    soh.CustomerID                                     AS ClienteKey,
    soh.TerritoryID                                    AS TerritorioKey,
    sod.ProductID                                      AS ProductoKey,
    soh.SalesPersonID                                  AS VendedorKey,
    sod.OrderQty,
    sod.UnitPrice,
    sod.UnitPriceDiscount,
    sod.LineTotal
INTO dbo.Fact_Ventas
FROM Sales.SalesOrderDetail sod
JOIN Sales.SalesOrderHeader soh ON soh.SalesOrderID = sod.SalesOrderID;

-- ------------------------------------------------------------
-- Números para la demo: comparar contra dbo.Ventas_Plano
-- ------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM dbo.Fact_Ventas)     AS Filas_Hechos,
    (SELECT COUNT(*) FROM dbo.Dim_Producto)    AS Filas_DimProducto,
    (SELECT COUNT(*) FROM dbo.Dim_Cliente)     AS Filas_DimCliente,
    (SELECT COUNT(*) FROM dbo.Dim_Territorio)  AS Filas_DimTerritorio,
    (SELECT COUNT(*) FROM dbo.Dim_Vendedor)    AS Filas_DimVendedor,
    (SELECT COUNT(*) FROM dbo.Dim_Fecha)       AS Filas_DimFecha;

-- Tamaño real en disco de las 6 tablas juntas (para comparar contra Ventas_Plano)
EXEC sp_spaceused 'dbo.Fact_Ventas';
EXEC sp_spaceused 'dbo.Dim_Producto';
EXEC sp_spaceused 'dbo.Dim_Cliente';
EXEC sp_spaceused 'dbo.Dim_Territorio';
EXEC sp_spaceused 'dbo.Dim_Vendedor';
EXEC sp_spaceused 'dbo.Dim_Fecha';
