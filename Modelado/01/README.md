# Artículo #1 de 52 · "Tu modelo no es lento, es plano"

Q1 · Cimientos · Semana 1 · Pieza de FONDO
Serie: *El modelo importa*

## Supuesto de partida

La demo usa **AdventureWorksDW2022** como fuente y reconstruye el mismo grano
de venta (una fila por línea de pedido) en dos formas distintas: una tabla
ancha y una estrella. El argumento de esta demo **no es la velocidad** —con
543.591 filas ambos motores resuelven una suma en milisegundos y esa
diferencia no es lo que hay que enseñar aquí. El argumento es la
**mantenibilidad**: cuántos sitios hay que tocar cuando cambia un dato de
negocio, y qué tan fácil es introducir un error sin darte cuenta.

## Qué hay en esta carpeta

```
demo/
├── README.md
├── 01_modelo_plano.sql           Crea Ventas_Plano contra AdventureWorks
│                                   OLTP: una tabla ancha, una fila por línea
│                                   de pedido, todo el contexto (cliente,
│                                   producto, territorio, vendedor) repetido
│                                   en cada fila.
├── 02_modelo_estrella.sql        Crea Fact_Ventas + Dim_Fecha, Dim_Producto,
│                                   Dim_Cliente, Dim_Territorio, Dim_Vendedor.
│                                   Mismo grano que Ventas_Plano.
├── 03_la_trampa.sql              El escenario que produce el número que
│                                   sorprende: añadir el histórico de
│                                   territorio del vendedor al modelo plano
│                                   duplica la venta total. No es un bug de
│                                   rendimiento, es un bug de mantenibilidad:
│                                   nadie decidió duplicar la venta, ocurrió
│                                   solo por cómo está construida la tabla.
├── 04_crear_demo_dw.sql          Script que prepara la base de datos local
│                                   de demo a partir de AdventureWorksDW2022
│                                   (la instancia de referencia no tiene el
│                                   OLTP), con un histórico didáctico de dos
│                                   periodos por vendedor.
├── medidas_comparacion.dax       Medidas para los modelos ya en Power BI:
│                                   ventas, año anterior y periodo paralelo,
│                                   en su versión plana y en su versión
│                                   estrella.
├── guion_video.md                Guión del vídeo de 3-5 min con timings,
│                                   qué mostrar en pantalla y dónde rellenar
│                                   los números reales.
├── csv/Ventas_Plano.csv          Muestra de datos sintética (297 filas) con
│                                   el mismo esquema que dbo.Ventas_Plano,
│                                   para poder abrir los proyectos *_csv sin
│                                   depender de una instancia de SQL Server.
├── Modelo_Plano.pbip             Modelo plano puro contra SQL Server: solo
│                                   Ventas_Plano, sin Dim_Fecha ni
│                                   inteligencia temporal automática. El
│                                   informe resuelve YoY y periodo paralelo
│                                   con DAX manual sobre OrderDate.
├── Modelo_Hibrido.pbip           Variante con Ventas_Plano y Dim_Fecha,
│                                   contra SQL Server: útil para mostrar que
│                                   al añadir un calendario el modelo plano
│                                   deja de ser estrictamente plano y pasa a
│                                   ser una miniestrella híbrida.
├── Modelo_Estrella.pbip          Modelo estrella independiente contra SQL
│                                   Server, con Fact_Ventas, las cinco
│                                   dimensiones y la página didáctica del
│                                   histórico.
├── Modelo_Plano_csv.pbip         Misma estructura que Modelo_Plano.pbip,
│                                   pero leyendo de csv/Ventas_Plano.csv en
│                                   vez de SQL Server. Sin dependencias.
├── Modelo_Hibrido_csv.pbip       Misma estructura que Modelo_Hibrido.pbip;
│                                   Dim_Fecha pasa a ser una tabla calculada
│                                   (CALENDAR) en vez de venir de SQL Server.
└── Modelo_Estrella_csv.pbip      Misma estructura que Modelo_Estrella.pbip;
                                    las cinco dimensiones se derivan del
                                    mismo CSV vía Table.Distinct.
```

## Cómo usarlo

### Opción A — Contra SQL Server (datos reales)

La instancia `a01p0717` no tiene AdventureWorks OLTP, sino `AdventureWorksDW2022`.
El script `04_crear_demo_dw.sql` crea la base `Demo_Modelo_Plano_Estrella`, conserva
los datos reales del DW y añade un histórico didáctico de dos filas por vendedor.
Ejecuta:

```powershell
sqlcmd -S a01p0717 -E -b -i .\04_crear_demo_dw.sql
```

Después abre `Modelo_Plano.pbip`, `Modelo_Hibrido.pbip` o `Modelo_Estrella.pbip`
en Power BI Desktop y actualiza las consultas.

### Opción B — Contra el CSV de ejemplo (sin dependencias)

Abre `Modelo_Plano_csv.pbip`, `Modelo_Hibrido_csv.pbip` o `Modelo_Estrella_csv.pbip`.
Cada uno lee `csv/Ventas_Plano.csv` a través del parámetro de Power Query
`RutaCarpetaDatos`. Si has clonado el repositorio en otra ruta:

1. Inicio > Transformar datos > Editar parámetros.
2. Cambia `RutaCarpetaDatos` a la carpeta local donde tengas `csv\` (con la
   barra invertida final).
3. Actualizar.

Esta variante es la que conviene enlazar en redes o para que cualquiera la
abra sin tener que levantar una base de datos.

Lecciones de compatibilidad PBIP aprendidas (aplican a ambas opciones):

- Cada carpeta `.Report` y `.SemanticModel` debe llevar su archivo `.platform`.
- Un informe que valida con el CLI puede seguir sin abrir en Desktop si falta esa
   metadata nativa (falta típica: `definition/version.json`).
- Los IDs físicos de páginas y visuales deben coincidir con sus nombres internos;
   no conviene usar nombres descriptivos como identificadores PBIR.
- Los comentarios `///` solo son válidos sobre `table`, `column` o `measure`; sobre
   una `annotation` se interpretan como una propiedad `description` que el
   parser rechaza.
- En una tabla calculada, el `sourceColumn` de una columna se referencia entre
   corchetes (`sourceColumn: [Date]`), no como texto plano — si no, la relación
   que use esa columna falla con un "Id. de columna no válido".
- Los filtros TopN deben revisarse por ámbito de `From` antes de atribuir el fallo
   al renderer o al modelo.

Resultados verificados en SQL:

- Modelo plano: 543.591 filas, venta total `264.228.103,9863`.
- Modelo estrella: 543.591 filas en el hecho, misma venta total.
- JOIN del histórico (el escenario de `03_la_trampa.sql`): 1.087.182 filas,
  venta total `528.456.207,9726` — el doble, sin que nadie haya cambiado un
  solo pedido real.

## Qué demuestra y qué no demuestra

- **Sí demuestra:** mismo total con ambos modelos, pero distinta distribución
  de responsabilidades. En el modelo plano, un atributo de producto (color,
  categoría, coste) vive repetido en cada línea de venta; corregirlo o
  ampliarlo significa tocar (o tener la certeza de haber tocado) todas las
  filas donde aparece. En el modelo estrella vive una vez, en la fila de la
  dimensión, y se corrige en un sitio.
- **Sí demuestra:** el histórico mal unido duplica filas y dinero. No es un
  fallo de sintaxis SQL ni de rendimiento: es lo que pasa cuando una tabla
  ancha intenta representar una relación que cambia en el tiempo (el
  territorio de un vendedor) sin un mecanismo explícito para versionarla. La
  estrella obliga a decidir esa relación una vez, en la dimensión; el modelo
  plano deja la decisión abierta a que alguien la vuelva a tomar mal en el
  futuro.
- **Sí demuestra:** las dimensiones permiten agrupar y filtrar sin acoplar el
  informe a cómo está escrita la tabla de hechos. Cambiar el nombre de un
  territorio, fusionar dos categorías de producto o corregir un vendedor mal
  asignado es una operación acotada y auditable en la dimensión, en vez de
  un `UPDATE` masivo (o una medida DAX que intenta compensar el problema).
- **No demuestra por sí solo:** que un modelo sea más rápido que otro. A esta
  escala esa comparación no es la que importa, y no es el objetivo de la
  demo.

La documentación de SQLBI sobre
[Understanding DAX Auto-Exist](https://www.sqlbi.com/articles/understanding-dax-auto-exist/)
es una buena referencia complementaria: explica por qué filtrar sobre
dimensiones distintas se comporta de forma diferente a filtrar sobre columnas
repetidas dentro de una misma tabla ancha — otro síntoma de por qué la forma
del modelo no es un detalle estético.

## Cómo comprobarlo tú mismo

1. Ejecuta `01_modelo_plano.sql` y `02_modelo_estrella.sql` (o `04_crear_demo_dw.sql`
   si partes de AdventureWorksDW2022) y anota filas y total de venta de cada uno.
2. Ejecuta `03_la_trampa.sql` y anota los dos resultados (A y B): esa
   diferencia es la escena central del vídeo.
3. En Power BI, prueba a añadir un atributo nuevo de producto (por ejemplo, un
   descuento por categoría) en ambos modelos y cuenta cuántos objetos hay que
   tocar en cada uno: en el plano, revisar cada medida que ya intenta
   compensar la repetición; en la estrella, una columna nueva en `Dim_Producto`.
4. Cambia el nombre de un territorio en ambos modelos y compara: un `UPDATE`
   de una fila en `Dim_Territorio` frente a localizar y corregir todas las
   filas de la tabla ancha que lo mencionan.
5. Rellena esos números en `guion_video.md` (están marcados como X, Y, A, B)
   y graba.
6. El PBIP resultante y los `.sql` son el activo descargable del post: van al
   repo, enlazados en el primer comentario, no en el cuerpo.

## Conexión con el artículo

El texto del artículo usa exactamente esta demo en su bloque "La demo". La
regla que se lleva el lector es la del guión: separar hechos de dimensiones
no es estilo, es lo que te obliga a decidir el grano una vez en vez de
accidentalmente cada vez que alguien pide una columna más o corrige un dato
mal escrito.
