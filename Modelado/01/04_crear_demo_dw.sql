-- Demo local para a01p0717 basada en AdventureWorksDW2022.
-- AdventureWorksDW no conserva histórico de vendedores, así que se crea
-- un historial didáctico de dos periodos por vendedor.

USE master;
GO

IF DB_ID(N'Demo_Modelo_Plano_Estrella') IS NULL
    CREATE DATABASE Demo_Modelo_Plano_Estrella;
GO

USE Demo_Modelo_Plano_Estrella;
GO

DROP TABLE IF EXISTS dbo.Dim_Vendedor_Historial;
DROP TABLE IF EXISTS dbo.Fact_Ventas;
DROP TABLE IF EXISTS dbo.Dim_Fecha;
DROP TABLE IF EXISTS dbo.Dim_Producto;
DROP TABLE IF EXISTS dbo.Dim_Cliente;
DROP TABLE IF EXISTS dbo.Dim_Territorio;
DROP TABLE IF EXISTS dbo.Dim_Vendedor;
DROP TABLE IF EXISTS dbo.Ventas_Plano;
GO

;WITH Vendedores AS (
    SELECT e.EmployeeKey AS VendedorKey,
           CONCAT(e.FirstName, N' ', e.LastName) AS NombreVendedor,
           COALESCE(MAX(e.SalesTerritoryKey), 1) AS TerritorioKey
    FROM AdventureWorksDW2022.dbo.DimEmployee e
    WHERE e.SalesPersonFlag = 1
    GROUP BY e.EmployeeKey, e.FirstName, e.LastName
), Lineas AS (
    SELECT f.*,
           ROW_NUMBER() OVER (ORDER BY f.SalesOrderNumber, f.SalesOrderLineNumber) AS NumeroLinea
    FROM AdventureWorksDW2022.dbo.FactInternetSales f
), VendedoresNumerados AS (
    SELECT Vendedores.*, ROW_NUMBER() OVER (ORDER BY VendedorKey) AS NumeroVendedor
    FROM Vendedores
), LineasConVendedor AS (
    SELECT l.*, v.VendedorKey
    FROM Lineas l
    JOIN VendedoresNumerados v
      ON v.NumeroVendedor = ((l.NumeroLinea - 1) % (SELECT COUNT(*) FROM VendedoresNumerados)) + 1
)
SELECT l.SalesOrderNumber, l.SalesOrderLineNumber, l.OrderDate, l.DueDate, l.ShipDate,
       l.CustomerKey AS ClienteID, CONCAT(c.FirstName, N' ', c.LastName) AS NombreCliente,
       l.SalesTerritoryKey AS TerritorioID, st.SalesTerritoryRegion AS Territorio,
       st.SalesTerritoryCountry AS Pais, l.ProductKey AS ProductoID,
       p.EnglishProductName AS Producto, p.Color, p.StandardCost, p.ListPrice,
       ps.EnglishProductSubcategoryName AS Subcategoria,
       pc.EnglishProductCategoryName AS Categoria, l.VendedorKey AS VendedorID,
       CONCAT(e.FirstName, N' ', e.LastName) AS NombreVendedor,
       l.OrderQuantity AS OrderQty, l.UnitPrice,
       l.UnitPriceDiscountPct AS UnitPriceDiscount, l.SalesAmount AS LineTotal
INTO dbo.Ventas_Plano
FROM LineasConVendedor l
JOIN AdventureWorksDW2022.dbo.DimCustomer c ON c.CustomerKey = l.CustomerKey
JOIN AdventureWorksDW2022.dbo.DimProduct p ON p.ProductKey = l.ProductKey
LEFT JOIN AdventureWorksDW2022.dbo.DimProductSubcategory ps ON ps.ProductSubcategoryKey = p.ProductSubcategoryKey
LEFT JOIN AdventureWorksDW2022.dbo.DimProductCategory pc ON pc.ProductCategoryKey = ps.ProductCategoryKey
JOIN AdventureWorksDW2022.dbo.DimSalesTerritory st ON st.SalesTerritoryKey = l.SalesTerritoryKey
JOIN AdventureWorksDW2022.dbo.DimEmployee e ON e.EmployeeKey = l.VendedorKey;
GO

SELECT DateKey AS FechaKey, FullDateAlternateKey AS Fecha, CalendarYear AS Anio,
       CalendarQuarter AS Trimestre, MonthNumberOfYear AS Mes,
       EnglishMonthName AS NombreMes, WeekNumberOfYear AS Semana,
       EnglishDayNameOfWeek AS DiaSemana
INTO dbo.Dim_Fecha
FROM AdventureWorksDW2022.dbo.DimDate;

SELECT p.ProductKey AS ProductoKey, p.EnglishProductName AS Producto, p.Color,
       p.StandardCost, p.ListPrice, ps.EnglishProductSubcategoryName AS Subcategoria,
       pc.EnglishProductCategoryName AS Categoria
INTO dbo.Dim_Producto
FROM AdventureWorksDW2022.dbo.DimProduct p
LEFT JOIN AdventureWorksDW2022.dbo.DimProductSubcategory ps ON ps.ProductSubcategoryKey = p.ProductSubcategoryKey
LEFT JOIN AdventureWorksDW2022.dbo.DimProductCategory pc ON pc.ProductCategoryKey = ps.ProductCategoryKey;

SELECT c.CustomerKey AS ClienteKey, CONCAT(c.FirstName, N' ', c.LastName) AS NombreCliente
INTO dbo.Dim_Cliente
FROM AdventureWorksDW2022.dbo.DimCustomer c;

SELECT SalesTerritoryKey AS TerritorioKey, SalesTerritoryRegion AS Territorio,
       SalesTerritoryCountry AS Pais, SalesTerritoryGroup AS Grupo
INTO dbo.Dim_Territorio
FROM AdventureWorksDW2022.dbo.DimSalesTerritory;

SELECT e.EmployeeKey AS VendedorKey, CONCAT(e.FirstName, N' ', e.LastName) AS NombreVendedor,
       MAX(e.SalesTerritoryKey) AS TerritorioKey
INTO dbo.Dim_Vendedor
FROM AdventureWorksDW2022.dbo.DimEmployee e
WHERE e.SalesPersonFlag = 1
GROUP BY e.EmployeeKey, e.FirstName, e.LastName;

SELECT v.SalesOrderNumber, v.SalesOrderLineNumber, v.OrderDateKey AS FechaKey,
       v.ClienteID AS ClienteKey, v.TerritorioID AS TerritorioKey,
    v.ProductoID AS ProductoKey, e.VendedorID AS VendedorKey,
       v.OrderQty, v.UnitPrice, v.UnitPriceDiscount, v.LineTotal
INTO dbo.Fact_Ventas
FROM (
    SELECT f.OrderDateKey, f.CustomerKey AS ClienteID, f.SalesTerritoryKey AS TerritorioID,
           f.ProductKey AS ProductoID, f.SalesOrderNumber, f.SalesOrderLineNumber,
           f.OrderQuantity AS OrderQty, f.UnitPrice,
           f.UnitPriceDiscountPct AS UnitPriceDiscount, f.SalesAmount AS LineTotal,
           ROW_NUMBER() OVER (ORDER BY f.SalesOrderNumber, f.SalesOrderLineNumber) AS NumeroLinea
    FROM AdventureWorksDW2022.dbo.FactInternetSales f
) v
JOIN (
    SELECT EmployeeKey AS VendedorID, ROW_NUMBER() OVER (ORDER BY EmployeeKey) AS NumeroVendedor
    FROM AdventureWorksDW2022.dbo.DimEmployee
    WHERE SalesPersonFlag = 1
) e ON e.NumeroVendedor = ((v.NumeroLinea - 1) % (SELECT COUNT(*) FROM AdventureWorksDW2022.dbo.DimEmployee WHERE SalesPersonFlag = 1)) + 1;

SELECT VendedorKey, NombreVendedor, 1 AS TerritorioKey,
       CAST('2005-01-01' AS date) AS Desde, CAST('2015-12-31' AS date) AS Hasta
INTO dbo.Dim_Vendedor_Historial
FROM dbo.Dim_Vendedor
UNION ALL
SELECT VendedorKey, NombreVendedor, TerritorioKey,
       CAST('2016-01-01' AS date), CAST('9999-12-31' AS date)
FROM dbo.Dim_Vendedor;
GO

CREATE INDEX IX_Ventas_Plano_Vendedor ON dbo.Ventas_Plano (VendedorID);
CREATE INDEX IX_Fact_Ventas_Vendedor ON dbo.Fact_Ventas (VendedorKey);
GO

SELECT COUNT(*) AS FilasPlano, COUNT(DISTINCT ClienteID) AS Clientes,
       COUNT(DISTINCT ProductoID) AS Productos, SUM(LineTotal) AS VentaTotal
FROM dbo.Ventas_Plano;
SELECT COUNT(*) AS FilasHecho, SUM(LineTotal) AS VentaTotal FROM dbo.Fact_Ventas;
GO