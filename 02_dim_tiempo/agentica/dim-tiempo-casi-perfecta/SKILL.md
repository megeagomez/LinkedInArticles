---
name: dim-tiempo-casi-perfecta
description: Genera y conecta en un modelo semántico de Power BI/Fabric la "dimensión de tiempo casi perfecta" (36 columnas, 5 jerarquías, calendario fiscal explícito, días laborables) desde una plantilla Jinja2, y crea relaciones "role-playing" (una activa + varias inactivas) hacia columnas de fecha de una tabla de hechos indicada en lenguaje natural. Úsala siempre que pidan crear, generar, completar o conectar una tabla o dimensión de fechas/calendario en un modelo semántico, aunque no mencionen "TMDL" ni "Jinja2" — p. ej. "necesito una tabla de fechas para este modelo", "conecta la dimensión de tiempo con Ventas por Fecha de Venta", "añade relaciones inactivas de fecha de entrega y envío", o "busca qué columnas de fecha me faltan por relacionar". No la uses para tablas de fechas fuera de un modelo semántico (Power Query suelto, T-SQL, PySpark) — para eso están los scripts de ../../scripts/, que esta skill reutiliza sin sustituir.
---

# dim-tiempo-casi-perfecta

Completa, en un modelo semántico real, el trabajo que documentan los 5
scripts de referencia de `../../scripts/` (Power Query, Tabular Editor, TMDL,
T-SQL, PySpark): generar la tabla de fechas con nombre configurable, y
conectarla a la(s) tabla(s) de hechos del modelo con el patrón de relaciones
"role-playing" (una activa, el resto inactivas).

No reinventes el TMDL a mano. La tabla ya está resuelta y validada en
`templates/dimension.tmdl.j2`; tu trabajo es reunir los parámetros correctos,
llamar a los scripts de render, y decidir si aplicarlos o solo mostrarlos.

## Regla de oro: pregunta antes de asumir

Esta skill necesita, como mínimo:

| Parámetro | Para qué | Si falta |
|---|---|---|
| `table_name` | Nombre de la tabla de fechas (no todo el mundo la llama "Fecha") | Pregúntalo; sugiere "Fecha" como valor por defecto pero no lo asumas sin confirmación si el usuario no lo dijo |
| `start_year` / `end_year` | Rango de años de la tabla | Pregunta, o propone un rango razonable (p.ej. año actual -5 a año actual +2) y pide confirmación |
| `fiscal_start_month` / `fiscal_year_basis` | Calendario fiscal | Si el usuario no menciona un año fiscal distinto del natural, pregunta si lo necesita antes de asumir que no |
| `mode` (`apply` o `show`) | Si se crean los objetos de verdad en el modelo o solo se enseña el TMDL | Pregúntalo siempre que no sea evidente por el contexto — aplicar cambios en un modelo real es una acción con consecuencias, no lo hagas por defecto |
| Para relaciones: tabla de hechos, columna(s) de fecha, cuál va activa | Sin esto no se puede generar `relationships.tmdl.j2` | Pregunta explícitamente cuál de las columnas mencionadas debe ser la relación activa si el usuario no lo dijo — no lo adivines (ver `references/relationship-tmdl.md`) |

Si el usuario te invoca con una petición vaga ("móntame la dimensión de
tiempo") sin estos datos, pregúntalos en una sola tanda de preguntas cortas
en vez de generar algo con valores inventados. Es mejor una pregunta que un
`createOrReplace` contra un modelo real con el nombre de tabla equivocado.

## Flujo de trabajo

### 1. Generar la tabla de fechas

Llama a `scripts/render_dimension.py` con los parámetros confirmados:

```bash
python scripts/render_dimension.py \
    --table-name "Fecha" \
    --start-year 2019 --end-year 2028 \
    --fiscal-start-month 6 --fiscal-year-basis End
```

Esto imprime el `createOrReplace` completo (tabla, 36 columnas en 5 carpetas,
5 jerarquías con el prefijo de orden — ver más abajo, medida `{table_name}_selection` (el nombre de tabla forma parte de la medida porque las medidas son únicas en todo el modelo, no solo dentro de su tabla — dos dimensiones de tiempo generadas con esta skill nunca chocan), los
4 parámetros del modelo) listo para ejecutar o mostrar. No edites el TMDL
resultante a mano: si necesitas un cambio estructural (una columna más, otra
jerarquía), edita `templates/dimension.tmdl.j2` y vuelve a renderizar, para
que el cambio quede en la plantilla y no se pierda la próxima vez.

**Sobre el orden en el árbol del modelo**: las 5 jerarquías llevan un espacio
inicial en el nombre (`' Calendar'`, `' Fiscal'`, ...) a propósito, para que
en la vista de modelo de Power BI Desktop / Tabular Editor aparezcan antes
que las carpetas de columnas (que no llevan ese espacio) — el árbol ordena
alfabéticamente y el espacio (código Unicode más bajo que cualquier letra)
gana el orden. Es un truco frágil por diseño: si el usuario reporta que su
versión de Desktop ordena distinto, es una señal de que esa vista usa
comparación por localización en vez de comparación literal de caracteres, y
el truco no aplica — dilo así, no insistas en "arreglarlo" con más espacios.

### 2. Generar las relaciones (si el usuario las pidió)

Lee `references/relationship-tmdl.md` antes de este paso — explica el patrón
de dimensión role-playing y las restricciones de `render_relationships.py`
(exactamente una relación activa por par tabla-hechos/tabla-dimensión).

Traduce la petición en lenguaje natural a una lista de relaciones. Ejemplo,
para "añade una relación con Ventas por Fecha de Venta, y tres inactivas con
Fecha Entrega, Fecha Envío y Fecha Factura":

```bash
python scripts/render_relationships.py \
    --rel "Ventas|Fecha de Venta|Fecha|Date|active" \
    --rel "Ventas|Fecha Entrega|Fecha|Date|inactive" \
    --rel "Ventas|Fecha Envio|Fecha|Date|inactive" \
    --rel "Ventas|Fecha Factura|Fecha|Date|inactive"
```

Si el usuario no dijo cuál debe ir activa, pregúntalo — no asumas que es la
primera que mencionó.

### 3. Descubrir columnas de fecha sin relacionar (opcional, bajo demanda)

Solo cuando el usuario lo pida ("busca qué más se puede relacionar", "¿me
falta alguna fecha por conectar?"), sigue `references/discovery.md`: usa la
skill `semantic-model-consumption` para inventariar columnas de fecha/hora en
el modelo y compararlas contra las relaciones existentes. Propón cada
candidata al usuario de forma explícita y añádela a la lista de
`render_relationships.py` solo si la acepta.

### 4. Aplicar o solo mostrar

- **Modo `show`** (por defecto si hay cualquier duda): imprime el TMDL
  generado en la respuesta, en un bloque de código, listo para que el
  usuario lo pegue en Tabular Editor 3 (Advanced Scripting → TMDL Script) o
  en la vista TMDL de Power BI Desktop. No toques el modelo real.
- **Modo `apply`**: usa la skill `semantic-model-authoring` para desplegar el
  TMDL generado contra el modelo semántico real (workspace/dataset que
  indique el usuario). Esta skill delega en `semantic-model-authoring` para
  la mecánica de despliegue — `DimTiempoCasiPerfecta` no habla directamente
  con las APIs de Fabric, genera el TMDL correcto y se lo pasa a la skill que
  ya sabe aplicarlo. Antes de aplicar, muestra igualmente el TMDL y pide
  confirmación explícita: aplicar contra un modelo real no es reversible sin
  esfuerzo.

## Ejemplo completo

> Usuario: "Crea la dimensión de tiempo en el modelo Ventas2026, año fiscal
> desde junio, y conéctala a la tabla Ventas por Fecha de Venta (activa),
> Fecha Entrega, Fecha Envío y Fecha Factura (inactivas). Aplícalo."

1. Parámetros ya dados: `table_name` no está — pregúntalo ("Fecha" por
   defecto, confirmar). `start_year`/`end_year` no están — pregúntalos.
   `fiscal_start_month=6`, `fiscal_year_basis` no está — pregúntalo (Start o
   End). `mode=apply` — dado explícitamente, pero confirma antes de ejecutar.
2. Render de la tabla (paso 1).
3. Render de las relaciones (paso 2), con `Fecha de Venta` como activa según
   lo dicho.
4. Muestra ambos TMDL, confirma con el usuario.
5. Invoca `semantic-model-authoring` para aplicarlos contra `Ventas2026`.

## Recursos de esta skill

- `templates/dimension.tmdl.j2` — plantilla de la tabla completa (única
  fuente de verdad; no dupliques su contenido a mano en ningún sitio).
- `templates/relationships.tmdl.j2` — plantilla de relaciones.
- `scripts/render_dimension.py`, `scripts/render_relationships.py` — únicos
  puntos de entrada para generar TMDL; requieren `jinja2` (`pip install
  jinja2` si no está disponible en el entorno).
- `references/relationship-tmdl.md` — patrón role-playing y sintaxis de
  relaciones TMDL, con las partes sin verificar contra Desktop marcadas como
  tal.
- `references/discovery.md` — consultas DAX/INFO para el sub-paso de
  descubrimiento.
- `../../scripts/` — las 5 implementaciones de referencia (M, C#, TMDL,
  T-SQL, PySpark) de las que sale la plantilla; y `../../articulo_*.md` — los
  dos artículos que documentan el diseño y los bugs encontrados por el
  camino. Si algo de esta skill no cuadra con lo que dicen esos artículos,
  los artículos describen el razonamiento — esta skill es la implementación.
