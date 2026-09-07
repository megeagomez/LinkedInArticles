# Sub-paso "agente de descubrimiento"

Objetivo: encontrar columnas de fecha/hora en el modelo que todavía no están
relacionadas con la dimensión de tiempo, y proponérselas al usuario — nunca
crear una relación sin que el usuario la acepte explícitamente para esa
columna en concreto.

## Paso 1 — inventario de columnas de fecha

Usa la skill `semantic-model-consumption` (o `az rest` directo si la skill no
está disponible) para ejecutar una consulta DAX basada en las funciones
`INFO.VIEW.*`. Antes de filtrar nada, ejecuta la versión sin filtrar una vez
para confirmar los nombres exactos de columna que devuelve tu versión del
motor (varían ligeramente entre versiones de Analysis Services/Fabric):

```dax
EVALUATE INFO.VIEW.COLUMNS()
```

Con los nombres de columna confirmados, filtra por tipo de dato fecha/hora y
excluye la propia tabla de la dimensión de tiempo (para no proponerle una
relación consigo misma):

```dax
EVALUATE
SELECTCOLUMNS(
    FILTER(
        INFO.VIEW.COLUMNS(),
        ( [DataType] = "dateTime" || [DataType] = "date" )
            && [Table] <> "<nombre_de_la_dimension_de_tiempo>"
    ),
    "TableName", [Table],
    "ColumnName", [Column]
)
```

## Paso 2 — relaciones que ya existen

```dax
EVALUATE
SELECTCOLUMNS(
    INFO.VIEW.RELATIONSHIPS(),
    "FromTable", [FromTable],
    "FromColumn", [FromColumn],
    "ToTable", [ToTable],
    "ToColumn", [ToColumn]
)
```

## Paso 3 — la diferencia es la lista de candidatas

Una columna de fecha del Paso 1 es candidata si su par (`TableName`,
`ColumnName`) **no aparece** como `FromColumn` de ninguna fila del Paso 2
hacia la tabla de la dimensión de tiempo. Esto se puede resolver en el propio
DAX con una anti-join (`EXCEPT` sobre las combinaciones de tabla+columna) o,
más simple, comparando las dos listas ya traídas a la conversación.

## Paso 4 — proponer, no crear

Por cada columna candidata, presenta al usuario una frase como:

> Encontré `Envios[Fecha Recepcion]` (tipo `dateTime`), sin relación con
> `Fecha`. ¿La añado como relación inactiva a `Fecha[Date]`? (s/n)

No añadas la relación a la lista que se pasa a `render_relationships.py`
hasta que el usuario responda que sí a esa columna en concreto. Si el usuario
dice que no, no la vuelvas a proponer en la misma sesión salvo que te lo
pida.

## Heurísticas para no ser pesado

- No propongas columnas que ya parezcan claves técnicas sin valor de negocio
  claro (por ejemplo `FechaCarga`, `FechaModificacion`, `ETLTimestamp`) sin
  avisar de que probablemente sea una columna de auditoría técnica y no un
  eje de análisis — pregunta igualmente, pero dilo explícitamente para que el
  usuario decida rápido.
- Si una tabla tiene más de 5 columnas de fecha candidatas, agrúpalas en una
  sola pregunta con una lista, no una pregunta por columna — el objetivo es
  ahorrarle trabajo al usuario, no generarle una entrevista larga.
