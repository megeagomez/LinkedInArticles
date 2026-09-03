# LinkedInArticles

Repositorio de apoyo para la serie **"El modelo importa"**: aquí iré subiendo
las demos (scripts SQL, medidas DAX, proyectos `.pbip`, notebooks o lo que
corresponda) de cada artículo o grupo de artículos que publico en LinkedIn.

Cada pieza vive en su propia subcarpeta, agrupada por bloque temático. La
carpeta contiene el código y los activos necesarios para reproducir la demo
del artículo, no el texto del artículo en sí (ese se publica en LinkedIn).

## Previsión

La serie son **52 piezas**, una por semana, publicadas los martes desde el
**25 de agosto de 2026** hasta el **17 de agosto de 2027**. No todas llevan
demo — las hay de tipo "Ligero", "Reto" o "Segunda opinión" que no siempre
requieren código — así que este repo irá creciendo de forma irregular a lo
largo de ese año, no con una carpeta nueva cada semana.

## Primer artículo

📂 [Modelado/01](Modelado/01) — **"Tu modelo no es lento: es plano"** (25 ago 2026)
Demo de comparación entre un modelo plano y un modelo en estrella sobre
AdventureWorksDW, con scripts SQL, medidas DAX y dos formas de abrir los
proyectos Power BI:

- **Contra SQL Server** — `Modelo_Plano`, `Modelo_Hibrido`, `Modelo_Estrella`:
  requieren la base de datos de demo (`04_crear_demo_dw.sql`).
- **Contra CSV** — `Modelo_Plano_csv`, `Modelo_Hibrido_csv`, `Modelo_Estrella_csv`:
  mismos modelos, leyendo de `csv/Ventas_Plano.csv` (datos de ejemplo
  sintéticos), sin dependencias externas. Es la forma recomendada de abrir
  la demo si solo quieres explorarla.

## Estructura

```
LinkedInArticles/
└── Modelado/
    └── 01/   ← primera demo del bloque "Modelado"
    └── ...   ← futuras demos del mismo bloque
```

A medida que se publiquen más piezas con demo, aparecerán nuevos bloques y
carpetas numeradas siguiendo el mismo patrón.
