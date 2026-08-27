-- ============================================================
-- MODELO PLANO — Artículo #1 de 52: "Tu modelo no es lento, es plano"
-- ============================================================
-- Qué es: la tabla que trae cualquiera que exporta "todo lo que
-- necesito para el informe" desde SQL a Power BI con una sola query,
-- sin separar hechos de dimensiones.
--
-- Grano: una fila por línea de pedido (SalesOrderDetail).
-- Base de datos: AdventureWorks2019 / AdventureWorks2022 (OLTP)
-- Requiere: SELECT sobre Sales.*, Production.*, Person.*
-- ============================================================

IF OBJECT_ID('dbo.Ventas_Plano', 'U') IS NOT NULL
    DROP TABLE dbo.Ventas_Plano;

SELECT
    sod.SalesOrderID,
    sod.SalesOrderDetailID,
    soh.OrderDate,
    soh.DueDate,
    soh.ShipDate,
    soh.Status                                       AS EstadoPedido,

    -- Cliente: se repite en cada línea de cada pedido de ese cliente
    c.CustomerID,
    p.FirstName,
    p.LastName,
    p.FirstName + ' ' + p.LastName                    AS NombreCliente,

    -- Territorio: se repite en cada línea
    st.TerritoryID,
    st.Name                                            AS Territorio,
    st.CountryRegionCode,

    -- Producto: se repite en cada línea vendida de ese producto
    pr.ProductID,
    pr.Name                                            AS Producto,
    pr.Color,
    pr.StandardCost,
    pr.ListPrice,
    psc.Name                                           AS Subcategoria,
    pc.Name                                            AS Categoria,

    -- Vendedor: se repite en cada línea
    soh.SalesPersonID                                  AS VendedorID,
    pv.FirstName + ' ' + pv.LastName                   AS NombreVendedor,

    -- Medidas de la línea (lo único que de verdad varía fila a fila)
    sod.OrderQty,
    sod.UnitPrice,
    sod.UnitPriceDiscount,
    sod.LineTotal
INTO dbo.Ventas_Plano
FROM Sales.SalesOrderDetail             sod
JOIN Sales.SalesOrderHeader             soh ON soh.SalesOrderID = sod.SalesOrderID
JOIN Sales.Customer                     c   ON c.CustomerID = soh.CustomerID
LEFT JOIN Person.Person                 p   ON p.BusinessEntityID = c.PersonID
JOIN Sales.SalesTerritory               st  ON st.TerritoryID = soh.TerritoryID
JOIN Production.Product                 pr  ON pr.ProductID = sod.ProductID
LEFT JOIN Production.ProductSubcategory psc ON psc.ProductSubcategoryID = pr.ProductSubcategoryID
LEFT JOIN Production.ProductCategory    pc  ON pc.ProductCategoryID = psc.ProductCategoryID
LEFT JOIN Person.Person                 pv  ON pv.BusinessEntityID = soh.SalesPersonID;

-- ------------------------------------------------------------
-- Números para la demo: cuánto se repite lo que no debería repetirse
-- ------------------------------------------------------------
SELECT
    COUNT(*)                        AS Filas_Totales,
    COUNT(DISTINCT CustomerID)      AS Clientes_Unicos,
    COUNT(DISTINCT ProductID)       AS Productos_Unicos,
    COUNT(DISTINCT Territorio)      AS Territorios_Unicos,
    -- cuántas veces se ha escrito en disco el mismo nombre de cliente
    COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT CustomerID), 0)  AS Filas_Por_Cliente_Promedio,
    COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT ProductID), 0)   AS Filas_Por_Producto_Promedio
FROM dbo.Ventas_Plano;

-- Tamaño real en disco de la tabla (para comparar contra el modelo en estrella)
EXEC sp_spaceused 'dbo.Ventas_Plano';
