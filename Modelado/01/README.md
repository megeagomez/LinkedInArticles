# Artículo #1 de 52 · "Tu modelo no es lento, es plano"

Q1 · Cimientos · Semana 1 · Pieza de FONDO
Serie: *El modelo importa*

## Supuesto de partida

La demo usa **AdventureWorksDW2022** como fuente y reconstruye dos modelos con
el mismo grano: una tabla ancha y una estrella. No pretende demostrar que una
suma desnuda siempre sea más lenta en el plano. Con 543.591 filas, el tiempo
local puede ser indistinguible; la comparación útil está en el tamaño,
cardinalidad, forma de los filtros y riesgo de duplicar hechos.

## Qué hay en esta carpeta

```
articulo-01-modelo-plano-vs-estrella/
├── README.md
├── sql/
│   ├── 01_modelo_plano.sql      Crea Ventas_Plano: una tabla ancha,
│   │                             una fila por línea de pedido, todo
│   │                             el contexto (cliente, producto,
│   │                             territorio, vendedor) repetido en
│   │                             cada fila.
│   ├── 02_modelo_estrella.sql   Crea Fact_Ventas + Dim_Fecha,
│   │                             Dim_Producto, Dim_Cliente,
│   │                             Dim_Territorio, Dim_Vendedor.
│   │                             Mismo grano que Ventas_Plano.
│   └── 03_la_trampa.sql         El escenario que produce el número
│                                 que sorprende: añadir el histórico
│                                 de territorio del vendedor al
│                                 modelo plano duplica la venta total.
├── dax/
│   └── medidas_comparacion.dax  Medidas para los dos modelos ya en
│                                 Power BI, más qué mirar en VertiPaq
│                                 Analyzer / DAX Studio.
└── guion/
    └── guion_video.md           Guión del vídeo de 3-5 min con
                                  timings, qué mostrar en pantalla y
                                  dónde rellenar los números reales.
```

## Cómo usarlo

### Demo local preparada

La instancia `a01p0717` no tiene AdventureWorks OLTP, sino `AdventureWorksDW2022`.
El script `04_crear_demo_dw.sql` crea la base `Demo_Modelo_Plano_Estrella`, conserva
los datos reales del DW y añade un histórico didáctico de dos filas por vendedor.
Ejecuta:

```powershell
sqlcmd -S a01p0717 -E -b -i .\04_crear_demo_dw.sql
```

Después abre uno de estos proyectos en Power BI Desktop y actualiza las
consultas:

- `Modelo_Plano.pbip`: modelo plano puro, solo `Ventas_Plano`, sin `Dim_Fecha` ni
   inteligencia temporal automática. El informe resuelve YoY y periodo paralelo
   con DAX manual sobre `OrderDate`.
- `Modelo_Hibrido.pbip`: variante con `Ventas_Plano` y `Dim_Fecha`, útil para
   mostrar que al añadir un calendario el modelo plano deja de ser estrictamente
   plano y pasa a ser una miniestrella híbrida.
- `Modelo_Estrella.pbip`: modelo estrella independiente, con `Fact_Ventas`,
   dimensiones y la página didáctica del histórico.

El antiguo `Modelo_Plano_Estrella.pbip` se conserva como referencia de la primera
versión combinada, pero no es el proyecto recomendado para la demo.

Lecciones de compatibilidad PBIP aprendidas:

- Cada carpeta `.Report` y `.SemanticModel` debe llevar su archivo `.platform`.
- Un informe que valida con el CLI puede seguir sin abrir en Desktop si falta esa
   metadata nativa.
- Los IDs físicos de páginas y visuales deben coincidir con sus nombres internos;
   no conviene usar nombres descriptivos como identificadores PBIR.
- Los comentarios `///` en relaciones TMDL pueden interpretarse como metadata;
   `relationships.tmdl` debe mantenerse limpio, sin comentarios entre relaciones.
- Los filtros TopN deben revisarse por ámbito de `From` antes de atribuir el fallo
   al renderer o al modelo.

Resultados verificados en SQL:

- Modelo plano: 543.591 filas, venta total `264.228.103,9863`.
- Modelo estrella: 543.591 filas en el hecho, misma venta total.
- JOIN del histórico: 1.087.182 filas, venta total `528.456.207,9726`.
- Tamaño SQL de referencia: plano `184336 KB`; estrella completa `59272 KB` reservados repartidos entre las tablas. El tamaño final de VertiPaq debe medirse en Power BI.

## Qué demuestra y qué no demuestra

- **Sí demuestra:** mismo total con ambos modelos, pero distinta distribución
   de responsabilidades; el histórico mal unido duplica filas y dinero; las
   dimensiones permiten agrupar y filtrar sin repetir atributos en el hecho.
- **No demuestra por sí solo:** que `SUM ( LineTotal )` tarde siempre más en la
   tabla plana. El motor columnar puede resolver esa consulta muy deprisa en
   ambos casos y el resultado depende de escala, cardinalidad, memoria y forma
   de la consulta.
- **La comprobación correcta:** medir con DAX Studio el total simple, una
   consulta `SUMMARIZECOLUMNS` con varios filtros, una lista `VALUES()` y el
   tamaño de diccionarios/columnas en VertiPaq Analyzer.

La documentación de SQLBI es una buena referencia para no exagerar el mensaje:
[Optimizing High Cardinality Columns in VertiPaq](https://www.sqlbi.com/articles/optimizing-high-cardinality-columns-in-vertipaq/)
explica el coste de los diccionarios de alta cardinalidad, mientras que
[Understanding DAX Auto-Exist](https://www.sqlbi.com/articles/understanding-dax-auto-exist/)
explica que los filtros sobre dimensiones distintas cambian el comportamiento
de `SUMMARIZECOLUMNS`. Son argumentos de escala y forma de consulta, no una
promesa de milisegundos para este dataset local.

1. Ejecuta `sql/01_modelo_plano.sql` y `sql/02_modelo_estrella.sql` contra tu
   AdventureWorks. Cada uno termina con un `SELECT` de números (filas,
   cardinalidad) y un `sp_spaceused` — anótalos, son la materia prima de la
   demo.
2. Ejecuta `sql/03_la_trampa.sql` y anota los dos resultados (A y B): esa
   diferencia es la escena central del vídeo.
3. Importa `Ventas_Plano` a un PBIX y `Fact_Ventas` + las 5 dimensiones a
   otro (o al mismo modelo con nombres claros). Aplica las medidas de
   `dax/medidas_comparacion.dax`.
4. Abre VertiPaq Analyzer sobre ambos y captura el tamaño del modelo y el
   tamaño de una columna repetitiva (`NombreCliente` o `Producto`) en cada
   uno.
5. Rellena esos números en `guion/guion_video.md` (están marcados como X, Y,
   A, B) y graba.
6. El PBIX resultante y los tres `.sql` son el activo descargable del post:
   van al repo, enlazados en el primer comentario, no en el cuerpo.

## Conexión con el artículo

El texto del artículo (plantilla en `Plan_editorial_52_semanas.md`, sección 6)
usa exactamente esta demo en su bloque "La demo". La regla que se lleva el
lector es la del guión: separar hechos de dimensiones no es estilo, es lo
que te obliga a decidir el grano una vez en vez de accidentalmente cada vez
que alguien pide una columna más.
