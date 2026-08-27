# Guión — Artículo #1 de 52 · "Tu modelo no es lento, es plano"

Pieza de FONDO · vídeo nativo 3–5 min · demo real en pantalla
Estructura: problema real → por qué falla la intuición → demo con números → regla que me llevo → pregunta a la audiencia

---

## 0:00–0:20 — Gancho + el problema

**En pantalla:** Power BI abierto con `Ventas_Plano` cargada, una medida `Venta Total Plano` en una tarjeta.

**Guión:**
> "Antes de enseñar números, una precisión: en esta demo una tarjeta con un `SUM` puede tardar prácticamente lo mismo en ambos modelos. Si buscabas una prueba teatral de que el plano siempre es más lento, no la vas a encontrar. La diferencia aparece cuando el informe crece: cardinalidad, filtros, memoria y riesgo de duplicar hechos."

Muestra rápido el `SELECT *` de una sola tabla (o el editor Power Query con un único origen) que trajo todos los datos a Power BI.

---

## 0:20–1:10 — Por qué falla la intuición

**En pantalla:** VertiPaq Analyzer abierto sobre `Ventas_Plano`, columna `NombreCliente` o `Producto` resaltada con su tamaño en MB.

**Guión:**
> "La intuición dice: 'una tabla grande es lenta, divídela y ya está'. Es demasiado simple. VertiPaq es columnar y puede comprimir muy bien una tabla plana; lo que tenemos que mirar es el diccionario y la cardinalidad de cada columna. En una tabla ancha, los atributos descriptivos viajan junto al hecho y el coste se repite a escala."

Señala en VertiPaq Analyzer el tamaño de esa columna concreto (rellenar con el número real tras ejecutar `01_modelo_plano.sql` + cargarla a Power BI).

> "Aquí: [X] MB solo en esta columna. En el modelo separado, ese dato vive una vez por cliente. No prometo un tiempo concreto: enseño una estructura que escala con menos repetición y hace explícito el grano."

---

## 1:10–3:00 — La demo (el núcleo del vídeo)

**Paso 1 — Tamaño del modelo.**
En pantalla: Información del archivo en Power BI, o VertiPaq Analyzer, con los dos modelos cargados (Ventas_Plano vs Fact_Ventas + 5 dimensiones).

> "Mismos datos, mismo grano, misma pregunta de negocio. Modelo plano: [X] MB. Modelo en estrella: [Y] MB. Este es un dato de huella, no una medición de duración de una sola consulta."

**Paso 1b — La consulta que puede empatar.**
En pantalla: DAX Studio con `SUM ( LineTotal )` y después una consulta agrupada por territorio y categoría.

> "El total simple puede empatar. La prueba útil es cambiar la forma de la pregunta: filtros de varias dimensiones, listas de valores y agrupaciones. Ahí el esquema deja de ser una preferencia visual y empieza a controlar qué columnas y qué relaciones tiene que recorrer el motor."

**Paso 2 — El número que sorprende (`03_la_trampa.sql`).**
En pantalla: pantalla partida — a la izquierda el resultado de la query A (sin histórico), a la derecha el resultado B (con histórico de territorio del vendedor añadido con el mismo tipo de JOIN de siempre).

> "Ahora alguien te pide un dato más: el histórico de territorio del vendedor. Un JOIN más, como todos los que ya tienes. Y mira lo que pasa con la venta total: de 264.228.103,9863 a 528.456.207,9726. Nadie ha vendido ni un euro más. La tabla plana no tiene dónde poner esa relación sin duplicar la línea de venta."

**Paso 3 — La misma pregunta en el modelo en estrella.**
En pantalla: el mismo dato añadido a `Dim_Vendedor` en el modelo en estrella; la medida `Venta Total Estrella` sin cambios.

> "En el modelo en estrella, ese histórico se cuelga de la dimensión de vendedor, nunca del hecho. La medida no cambia ni una línea. El modelo no elimina todos los errores posibles, pero hace visible el grano y reduce la probabilidad de convertir un atributo histórico en filas de venta duplicadas."

---

## 3:00–3:40 — La regla que me llevo

**En pantalla:** vuelve a cámara o a una diapositiva simple con la frase.

**Guión:**
> "La regla: no uses una tarjeta rápida como veredicto sobre el modelo. Mide huella, cardinalidad, filtros y consultas agrupadas; y protege el grano. Separar hechos de dimensiones no es una regla de estilo: es una forma de hacer explícita esa decisión antes de que un JOIN o un nuevo atributo cambie el significado de tus números."

---

## 3:40–4:00 — Pregunta a la audiencia

> "¿Cuál fue el número que no te cuadraba y que, mirándolo con calma, resultó ser exactamente esto? Cuéntamelo en los comentarios."

---

## Notas de producción

- Subtítulos quemados siempre (formato 1:1 o 4:5, nunca 16:9).
- Antes de grabar: ejecutar `04_crear_demo_dw.sql` en `a01p0717`, actualizar `Modelo_Plano.pbip` y `Modelo_Estrella.pbip`, y rellenar X/Y con los tamaños VertiPaq que muestre Power BI. Los valores A/B ya están calculados: 543.591 filas y 264.228.103,9863 de venta frente a 1.087.182 filas y 528.456.207,9726 tras el JOIN histórico.
- El activo descargable del post: los tres scripts SQL + el PBIX con los dos modelos, al repo, enlazado en el primer comentario.
