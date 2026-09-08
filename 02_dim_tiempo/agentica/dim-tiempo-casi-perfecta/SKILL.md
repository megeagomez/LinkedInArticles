---
name: dim-tiempo-casi-perfecta
description: Genera la "dimensión de tiempo casi perfecta" (36 columnas, 5 jerarquías, calendario fiscal, días laborables) en 4 orígenes — TMDL de modelo semántico Power BI/Fabric, Power Query M suelto, T-SQL para Warehouse/Lakehouse, o PySpark para notebook Fabric — desde plantillas Jinja2, con validación estática siempre y test real opcional contra un destino que indique el usuario. En Fabric/TMDL además crea relaciones "role-playing" (una activa + varias inactivas) hacia columnas de fecha de una tabla de hechos en lenguaje natural. Úsala siempre que pidan crear o completar una tabla/dimensión de fechas o calendario, en cualquiera de esos 4 formatos, aunque no mencionen "TMDL" ni el origen exacto — p. ej. "tabla de fechas para este modelo", "Power Query de la dimensión de tiempo", "T-SQL de la tabla de fechas para el Warehouse", "dimensión de tiempo en PySpark", "conecta la dimensión de tiempo con Ventas por Fecha de Venta".
---

# dim-tiempo-casi-perfecta

Genera, en cualquiera de sus 4 orígenes, el trabajo que documentan los 5
scripts de referencia de `../../scripts/` (Power Query, Tabular Editor, TMDL,
T-SQL, PySpark): la tabla de fechas con nombre y calendario configurables. En
el origen Fabric/TMDL, además conecta la tabla a la(s) tabla(s) de hechos del
modelo con el patrón de relaciones "role-playing" (una activa, el resto
inactivas) y puede desplegarla contra un modelo semántico real.

No reinventes ningún formato a mano. Las 4 salidas ya están resueltas y
validadas en `templates/*.j2`; tu trabajo es reunir los parámetros correctos,
llamar a los scripts de render, y decidir si aplicarlos/probarlos o solo
mostrarlos.

## Paso 0: pregunta el origen

Antes de pedir ningún parámetro, pregunta qué origen necesita el usuario —
no lo adivines por el contexto del repo o del workspace abierto, pregúntalo
explícitamente salvo que el usuario ya lo haya dicho sin ambigüedad ("dame
el T-SQL", "esto es para un notebook PySpark"):

| Origen | Qué genera | Script de render | Plantilla |
|---|---|---|---|
| **Fabric** | `createOrReplace` TMDL de una tabla de modelo semántico (Power BI / Fabric), con jerarquías y medida de selección | `scripts/render_dimension.py` | `templates/dimension.tmdl.j2` |
| **M** | Power Query M autocontenido (Advanced Editor / Dataflow Gen2) | `scripts/render_powerquery.py` | `templates/powerquery_m.pq.j2` |
| **SQL** | T-SQL `CREATE TABLE ... AS SELECT` para Fabric Warehouse (o lectura desde Lakehouse SQL endpoint) | `scripts/render_tsql.py` | `templates/tsql_dimfecha.sql.j2` |
| **PySpark** | Notebook de Fabric, celda a celda, que escribe una tabla Delta en un Lakehouse | `scripts/render_pyspark.py` | `templates/pyspark_dimfecha.py.j2` |

Si el usuario pide más de un origen a la vez ("dame el TMDL y también el
T-SQL por si acaso"), trátalo como varias pasadas del flujo completo, una
por origen — no mezcles parámetros de una con otra sin confirmarlo (p. ej.
el nombre de tabla puede ser distinto en cada uno).

## Regla de oro: pregunta antes de asumir

Todos los orígenes comparten estos parámetros de calendario:

| Parámetro | Para qué | Si falta |
|---|---|---|
| `start_year` / `end_year` | Rango de años de la tabla | Pregunta, o propone un rango razonable (p.ej. año actual -5 a año actual +2) y pide confirmación |
| `fiscal_start_month` / `fiscal_year_basis` | Calendario fiscal | Si el usuario no menciona un año fiscal distinto del natural, pregunta si lo necesita antes de asumir que no |

Y cada origen añade lo suyo:

| Origen | Parámetro adicional | Si falta |
|---|---|---|
| Fabric | `table_name` | Pregúntalo; sugiere "Fecha" como valor por defecto pero no lo asumas sin confirmación |
| Fabric | `mode` (`apply` o `show`) | Pregúntalo siempre que no sea evidente por el contexto — aplicar cambios en un modelo real es una acción con consecuencias, no lo hagas por defecto |
| Fabric (si piden relaciones) | tabla de hechos, columna(s) de fecha, cuál va activa | Pregunta explícitamente cuál va activa si el usuario no lo dijo — no lo adivines (ver `references/relationship-tmdl.md`) |
| SQL | `schema_name` / `table_name` | Sugiere `dbo` / `DimFecha` por defecto, confirma. El render rechaza nombres que no sean identificadores simples (protección contra inyección al construir el `CREATE TABLE`) |
| PySpark | `table_name` (admite `schema.tabla`) | Sugiere `DimFecha` por defecto, confirma |
| M | — (no necesita nombre de tabla: el nombre lo pone el propio dataflow/consulta al guardarla) | — |

Si el usuario te invoca con una petición vaga ("móntame la dimensión de
tiempo") sin estos datos, pregúntalos en una sola tanda de preguntas cortas
en vez de generar algo con valores inventados. Es mejor una pregunta que un
render con el nombre de tabla equivocado, o un `createOrReplace` contra un
modelo real con parámetros no confirmados.

## Flujo de trabajo

### 1. Generar el código del origen elegido

Llama al script de render correspondiente (ver tabla del paso 0) con los
parámetros confirmados. Ejemplos:

```bash
# Fabric
python scripts/render_dimension.py \
    --table-name "Fecha" \
    --start-year 2019 --end-year 2028 \
    --fiscal-start-month 6 --fiscal-year-basis End

# M
python scripts/render_powerquery.py \
    --start-year 2019 --end-year 2028 \
    --fiscal-start-month 6 --fiscal-year-basis End

# SQL
python scripts/render_tsql.py \
    --schema-name dbo --table-name DimFecha \
    --start-year 2019 --end-year 2028 \
    --fiscal-start-month 6 --fiscal-year-basis End

# PySpark
python scripts/render_pyspark.py \
    --table-name DimFecha \
    --start-year 2019 --end-year 2028 \
    --fiscal-start-month 6 --fiscal-year-basis End
```

Cada uno imprime el código completo listo para ejecutar o mostrar. No edites
el resultado a mano: si necesitas un cambio estructural (una columna más,
otra jerarquía), edita la plantilla `.j2` correspondiente y vuelve a
renderizar, para que el cambio quede en la plantilla y no se pierda la
próxima vez.

**Sobre el orden en el árbol del modelo (solo Fabric)**: las 5 jerarquías
llevan un espacio inicial en el nombre (`' Calendar'`, `' Fiscal'`, ...) a
propósito, para que en la vista de modelo de Power BI Desktop / Tabular
Editor aparezcan antes que las carpetas de columnas — el árbol ordena
alfabéticamente y el espacio (código Unicode más bajo que cualquier letra)
gana el orden. Es un truco frágil por diseño: si el usuario reporta que su
versión de Desktop ordena distinto, es señal de que esa vista usa
comparación por localización en vez de comparación literal, y el truco no
aplica — dilo así, no insistas en "arreglarlo" con más espacios.

### 2. Validación estática (siempre, sin pedir permiso)

Pasa la salida por `scripts/validate_syntax.py --origin {fabric|m|sql|pyspark}`.
Es solo análisis de texto local — nunca toca red ni infraestructura, así que
se aplica siempre, sin confirmación. Para PySpark es una comprobación real
(`ast.parse` de Python); para Fabric/M/SQL es un balance de paréntesis y
llaves más comprobación de palabras clave — un heurístico, no un parser real
(ver docstring del script y `references/testing.md` para el detalle). Si
falla, no se lo enseñes al usuario como si fuera válido: dile qué encontró
mal y vuelve a renderizar si el problema es un parámetro, o revisa la
plantilla si el problema es estructural.

### 3. Relaciones (solo origen Fabric, si el usuario las pidió)

Lee `references/relationship-tmdl.md` antes de este paso — explica el patrón
de dimensión role-playing y las restricciones de `render_relationships.py`
(exactamente una relación activa por par tabla-hechos/tabla-dimensión).

```bash
python scripts/render_relationships.py \
    --rel "Ventas|Fecha de Venta|Fecha|Date|active" \
    --rel "Ventas|Fecha Entrega|Fecha|Date|inactive" \
    --rel "Ventas|Fecha Envio|Fecha|Date|inactive" \
    --rel "Ventas|Fecha Factura|Fecha|Date|inactive"
```

Si el usuario no dijo cuál debe ir activa, pregúntalo — no asumas que es la
primera que mencionó.

### 4. Descubrir columnas de fecha sin relacionar (solo Fabric, opcional, bajo demanda)

Solo cuando el usuario lo pida ("busca qué más se puede relacionar", "¿me
falta alguna fecha por conectar?"), sigue `references/discovery.md`: usa la
skill `semantic-model-consumption` para inventariar columnas de fecha/hora en
el modelo y compararlas contra las relaciones existentes. Propón cada
candidata al usuario de forma explícita y añádela a la lista de
`render_relationships.py` solo si la acepta.

### 5. ¿Test real contra un destino vivo?

Con la validación estática ya hecha (paso 2), pregunta explícitamente al
usuario si además quiere probarlo de verdad contra un destino real, o si
prefiere quedarse con el código validado para procesarlo él mismo más
adelante — no lo asumas en ningún sentido. Lee `references/testing.md` antes
de este paso: ahí está, por origen, qué skill delega la ejecución
(`semantic-model-authoring`/`semantic-model-consumption` para Fabric,
`sqldw-authoring-cli`/`sqldw-consumption-cli` para SQL, el preview de
`dataflows-authoring-cli` para M, `spark-consumption-cli` para PySpark) y qué
consulta de sanity check confirma que la tabla generada tiene las filas y el
rango de fechas esperados.

Si el usuario quiere el test real: pide el destino (workspace, y
warehouse/lakehouse/dataset según el origen) si no lo dio, confirma
explícitamente antes de ejecutar/aplicar — no es una acción reversible sin
esfuerzo — y después de ejecutarlo corre la consulta de sanity check
correspondiente y enséñale el resultado.

Si no lo quiere (o solo pide validación estática, como mínimo): entrega el
código ya validado, dile explícitamente que no se ha ejecutado contra
ningún destino real, y señálale las consultas de sanity check que ya vienen
comentadas en cada plantilla para cuando lo procese por su cuenta.

### 6. Aplicar o solo mostrar (específico del origen)

- **Fabric, modo `show`** (por defecto si hay cualquier duda): imprime el
  TMDL en la respuesta, en un bloque de código, listo para pegarlo en
  Tabular Editor 3 (Advanced Scripting → TMDL Script) o en la vista TMDL de
  Power BI Desktop. No toques el modelo real.
- **Fabric, modo `apply`**: usa la skill `semantic-model-authoring` para
  desplegar el TMDL contra el workspace/dataset que indique el usuario.
  Antes de aplicar, muestra igualmente el TMDL y pide confirmación
  explícita.
- **M, SQL, PySpark**: por defecto, entrega el código para que el usuario lo
  pegue donde corresponda (Advanced Editor / script de Warehouse / celda de
  notebook). Solo lo ejecutas tú si el usuario pidió el test real del paso 5
  y confirmó el destino.

## Ejemplo completo (origen Fabric)

> Usuario: "Crea la dimensión de tiempo en el modelo Ventas2026, año fiscal
> desde junio, y conéctala a la tabla Ventas por Fecha de Venta (activa),
> Fecha Entrega, Fecha Envío y Fecha Factura (inactivas). Aplícalo."

1. Origen ya dado por el contexto ("modelo Ventas2026") — Fabric/TMDL, sin
   necesidad de preguntarlo.
2. Parámetros: `table_name` no está — pregúntalo ("Fecha" por defecto,
   confirmar). `start_year`/`end_year` no están — pregúntalos.
   `fiscal_start_month=6`, `fiscal_year_basis` no está — pregúntalo (Start o
   End). `mode=apply` — dado explícitamente, pero confirma antes de
   ejecutar.
3. Render de la tabla (paso 1) y validación estática (paso 2).
4. Render de las relaciones (paso 3), con `Fecha de Venta` como activa según
   lo dicho.
5. Pregunta si además quiere el test real (paso 5) — en este ejemplo ya dijo
   "aplícalo", así que aplicar y verificar con una consulta DAX cuenta como
   ese test.
6. Muestra ambos TMDL, confirma con el usuario.
7. Invoca `semantic-model-authoring` para aplicarlos contra `Ventas2026`, y
   `semantic-model-consumption` para el DAX de sanity check.

## Ejemplo completo (origen SQL)

> Usuario: "Necesito el T-SQL de la dimensión de tiempo para el Warehouse,
> 2018 a 2027, año fiscal natural. Pruébalo contra WarehouseVentas si puedes."

1. Origen: SQL, dado explícitamente.
2. Parámetros: `schema_name`/`table_name` no están — pregúntalos (`dbo` /
   `DimFecha` por defecto, confirmar). `start_year=2018`, `end_year=2027`
   dados. "Año fiscal natural" = sin desplazamiento — confirma
   `fiscal_start_month=1`, pregunta `fiscal_year_basis` si hace falta
   distinguir (con mes 1 da igual Start o End, dilo así en vez de preguntar
   algo irrelevante).
3. Render (paso 1) y validación estática (paso 2) — sin pasos 3/4 (son solo
   de Fabric).
4. El usuario ya pidió el test real contra `WarehouseVentas` (paso 5):
   confirma el workspace/warehouse exacto, ejecuta vía `sqldw-authoring-cli`,
   y verifica con el `SELECT COUNT(*)` de sanity check vía
   `sqldw-consumption-cli`.
5. Entrega el T-SQL y el resultado del sanity check.

## Recursos de esta skill

- `templates/dimension.tmdl.j2`, `templates/relationships.tmdl.j2` —
  plantillas del origen Fabric (única fuente de verdad; no dupliques su
  contenido a mano en ningún sitio).
- `templates/powerquery_m.pq.j2` — plantilla del origen M.
- `templates/tsql_dimfecha.sql.j2` — plantilla del origen SQL.
- `templates/pyspark_dimfecha.py.j2` — plantilla del origen PySpark.
- `scripts/render_dimension.py`, `scripts/render_relationships.py`,
  `scripts/render_powerquery.py`, `scripts/render_tsql.py`,
  `scripts/render_pyspark.py` — únicos puntos de entrada para generar cada
  origen; requieren `jinja2` (`pip install jinja2` si no está disponible en
  el entorno).
- `scripts/validate_syntax.py` — validación estática obligatoria del paso 2,
  para los 4 orígenes.
- `references/relationship-tmdl.md` — patrón role-playing y sintaxis de
  relaciones TMDL (solo Fabric).
- `references/discovery.md` — consultas DAX/INFO para el sub-paso de
  descubrimiento (solo Fabric).
- `references/testing.md` — qué significa el test real en cada origen, qué
  skill lo ejecuta, y qué consulta de sanity check confirma que funcionó.
- `../../scripts/` — las 5 implementaciones de referencia (M, C#, TMDL,
  T-SQL, PySpark) de las que salen las plantillas de esta skill; y
  `../../articulo_*.md` — los dos artículos que documentan el diseño y los
  bugs encontrados por el camino. Si algo de esta skill no cuadra con lo que
  dicen esos artículos, los artículos describen el razonamiento — esta
  skill es la implementación.
