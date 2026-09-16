# Probar que funciona: validación estática vs. test real

Todo render pasa siempre por `scripts/validate_syntax.py` (ver su docstring
para el detalle exacto de qué comprueba cada origen — es solo texto local,
nunca toca una red, así que se aplica siempre sin pedir permiso). Eso es el
suelo mínimo, no el techo: no es lo mismo "el texto no tiene una llave sin
cerrar" que "esto corre de verdad contra un Warehouse o un modelo real".

Por eso, después de la validación estática, pregunta explícitamente al
usuario si quiere además un **test real** contra un destino vivo. No lo
asumas ni en un sentido ni en el otro — depende de si el usuario ya tiene el
destino a mano (workspace, warehouse, lakehouse) y de si quiere que la skill
toque infraestructura real ahora mismo o prefiere quedarse en modo
"enséñame el código, ya lo probaré yo cuando procese la dimensión". Aplicar
o ejecutar contra un destino real no es una acción reversible sin esfuerzo,
así que confirma explícitamente el destino y la acción antes de lanzarla,
igual que ya hace el flujo existente para el modo `apply` de Fabric/TMDL.

## Qué significa "test real" en cada origen

### Fabric (TMDL de modelo semántico)

Ya está resuelto por el flujo existente: modo `apply` con la skill
`semantic-model-authoring` despliega el `createOrReplace` contra el
workspace/dataset que indique el usuario. Como verificación adicional tras
aplicar, usa `semantic-model-consumption` para lanzar una consulta DAX rápida
contra la tabla recién creada, por ejemplo:

```dax
EVALUATE TOPN(5, '{table_name}')
EVALUATE ROW("Filas", COUNTROWS('{table_name}'), "Min", MIN('{table_name}'[Date]), "Max", MAX('{table_name}'[Date]))
```

Si la consulta devuelve filas con el rango de años esperado, el test real ha
pasado.

### SQL (T-SQL para Warehouse / Lakehouse SQL endpoint)

Pide el workspace y el Warehouse/Lakehouse de destino si el usuario no los
dio. Usa `sqldw-authoring-cli` (o el flujo que esa skill indique) para
ejecutar el script renderizado contra ese destino. Después, usa
`sqldw-consumption-cli` para una verificación de sanity — las mismas
consultas que ya vienen comentadas al final de la plantilla:

```sql
SELECT COUNT(*) AS Filas, MIN([Date]) AS Min_Fecha, MAX([Date]) AS Max_Fecha FROM {schema_name}.{table_name};
```

Si el conteo de filas coincide con los días del rango pedido (`end_year -
start_year + 1` años, contando bisiestos), el test real ha pasado.

### M (Power Query suelto)

No hace falta guardar un dataflow para probar que el M compila y produce
filas: `dataflows-authoring-cli` documenta un bucle de preview
(`executeQuery` + `customMashupDocument`) pensado exactamente para esto —
validar M antes de persistirlo. Pide el workspace de destino si el usuario
quiere que además quede guardado como Dataflow Gen2; si solo quiere
comprobar que compila y da resultados razonables, el preview solo no
requiere guardar nada.

### PySpark (notebook de Fabric)

Hay dos formas de probarlo de verdad, según lo que el usuario pidió:

- **Ad hoc, sin desplegar nada**: pide el workspace y el Lakehouse de
  destino. Usa `spark-consumption-cli` para abrir una sesión Livy y ejecutar
  el script celda a celda (o el bloque completo) contra ese Lakehouse. La
  verificación de sanity son las mismas líneas que ya vienen comentadas al
  final de la plantilla (CELL 9): conteo de filas, rango de fechas, y una
  fila de "hoy" con sus banderas `Current *`.
- **Como ítem Notebook desplegado** (si el usuario generó el `.ipynb` con
  `scripts/render_notebook.py`, paso 1bis de la skill, y quiere que quede
  creado en un workspace, no solo probado): usa `spark-authoring-cli` para
  crear/actualizar el ítem Notebook con esa definición en el workspace
  indicado, con el lakehouse de destino como lakehouse por defecto.
  Ejecutarlo (con o sin sobrescribir la celda `"parameters"`) materializa la
  tabla Delta exactamente igual que el CTAS de SQL Server materializa
  `DimFecha` — es el paso que de verdad "crea los datos". Verifica después
  con la misma consulta de sanity check de la sección SQL de arriba
  (`SELECT COUNT(*) AS Filas, MIN([Date])..., MAX([Date])...`) contra el SQL
  endpoint del Lakehouse, vía `sqldw-consumption-cli` — un Lakehouse expone
  ese endpoint igual que un Warehouse, así que la misma consulta sirve para
  los dos.

## Si el usuario no quiere test real

Queda igual de bien resuelto: entrega el código ya validado
estáticamente, dile explícitamente qué NO se ha probado (no se ha ejecutado
contra ningún destino real), y para qué sirve cada una de las consultas de
sanity check ya comentadas en la plantilla — así, cuando el usuario lo
procese por su cuenta, sabe qué mirar para confirmar que funciona.
