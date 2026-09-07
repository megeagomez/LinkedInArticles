# Relaciones "role-playing": patrón y sintaxis TMDL

## El patrón

Una sola tabla de fechas física puede relacionarse con varias columnas de
fecha de la misma tabla de hechos (`Fecha de Venta`, `Fecha Entrega`, `Fecha
Envío`, `Fecha Factura`...). Esto se llama dimensión "role-playing": la misma
dimensión juega varios papeles distintos según qué columna la conecta.

La regla que no se puede romper: **de todas las relaciones entre un mismo par
de tablas, exactamente una puede estar activa**. Solo la relación activa
propaga filtros automáticamente (por eso una matriz con `Fecha[Year]` en
filas suma "Ventas" filtrado por la fecha activa, casi siempre `Fecha de
Venta`). Las demás quedan inactivas (`isActive: false`) y se activan a mano,
por medida, con `USERELATIONSHIP()`:

```dax
Ventas por Fecha Entrega =
CALCULATE(
    [Ventas],
    USERELATIONSHIP('Ventas'[Fecha Entrega], 'Fecha'[Date])
)
```

`scripts/render_relationships.py` fuerza esta regla en el momento de generar
el TMDL: si le pasas dos relaciones activas para el mismo par de tablas,
falla con un error explícito en vez de generar un modelo ambiguo.

## Sintaxis TMDL de una relación

```
	relationship 'Ventas_FechaDeVenta_Fecha'
		fromColumn: 'Ventas'.'Fecha de Venta'
		toColumn: 'Fecha'.'Date'

	relationship 'Ventas_FechaEntrega_Fecha'
		isActive: false
		fromColumn: 'Ventas'.'Fecha Entrega'
		toColumn: 'Fecha'.'Date'
```

Notas:

- `isActive: false` es la única línea que distingue una relación inactiva de
  una activa (el valor por defecto de `isActive` es `true`, así que se omite
  en la relación activa).
- Por defecto la cardinalidad es `many` (lado "fromColumn") a `one` (lado
  "toColumn") y el filtro cruza en una sola dirección — el caso normal de
  hechos → dimensión. Si en tu modelo necesitas otra cosa (bidireccional,
  uno a uno), añade `crossFilteringBehavior: bothDirections` o
  `fromCardinality`/`toCardinality` explícitos; no lo hace falta en el caso
  estándar de esta skill.
- **Sin verificar contra un export real de Desktop**: el nombre de la
  relación (`relationship 'Ventas_FechaDeVenta_Fecha'`) usa un token legible
  en vez del GUID que suelen llevar las relaciones en un TMDL exportado.
  Igual que aprendimos con `lineageTag` (no hace falta ponerlo — Desktop
  genera el suyo), es razonable esperar que un nombre legible también
  funcione al ejecutar el script `createOrReplace`, pero **la primera vez
  que uses esto en Power BI Desktop, confírmalo** y, si falla, prueba
  sustituyendo el nombre por un GUID cualquiera (formato
  `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) — Desktop debería aceptar
  cualquiera de las dos formas si el patrón de tabla+expresiones enseñó algo
  generalizable.
- Igual que con la tabla de fechas: **un único `createOrReplace` puede cubrir
  varias relaciones a la vez** (una activa + N inactivas), sin necesidad de
  ejecutar un script por relación — así es como lo genera
  `render_relationships.py`. Esto es una extrapolación directa de lo que ya
  confirmamos con `03_Fecha.tmdl` (tabla + 4 parámetros en un solo
  `createOrReplace`), pero no se ha probado específicamente con relaciones;
  valídalo la primera vez.

## Cuándo NO usar este patrón

Si dos columnas de fecha en la tabla de hechos representan conceptos que de
verdad quieres analizar simultáneamente en el mismo informe con filtros
independientes (por ejemplo, "ventas facturadas en marzo pero entregadas en
abril"), una única dimensión con relaciones inactivas obliga a escribir una
medida por combinación. Si ese es tu caso de uso principal, plantéate una
segunda tabla de fechas física (otra instancia de esta misma skill, con otro
`table_name`) en vez de forzarlo todo por `USERELATIONSHIP()`.
