#!/usr/bin/env python
"""Package the PySpark dimension script as a real, deployable Fabric notebook (.ipynb).

Same rationale as the other render_*.py scripts: don't hand-build the notebook
JSON, call this script so the same inputs always produce the same notebook.
It reuses render_pyspark.render() for the actual PySpark logic (single source
of truth: templates/pyspark_dimfecha.py.j2) and only adds the notebook
packaging on top — one cell per "# CELL N —" block, with the parameters cell
tagged ["parameters"] so a Fabric pipeline / notebook "Run" activity can
override start_year/end_year/table_name/etc. without editing the notebook,
exactly like a SQL Server job overrides @StartYear/@EndYear at execution time.

Usage:
    python render_notebook.py --table-name DimFecha \
        --start-year 2019 --end-year 2028 \
        --fiscal-start-month 6 --fiscal-year-basis End --language es \
        --workspace-name "Analytics Ventas" --lakehouse-name LH_Ventas

Prints the rendered .ipynb (JSON) to stdout. Redirect to a file, or hand it
to the skill that imports/updates a Notebook item in a Fabric workspace
(see references/testing.md — "Fabric notebook, desplegado" section).

--workspace-name/--lakehouse-name are optional: without them, the notebook
has no default lakehouse attached (metadata.dependencies is omitted) and
whoever opens it in the Fabric UI must attach one before running — the same
"show, don't touch infrastructure" default as the other origins. With them,
the notebook's default-lakehouse metadata is pre-filled, but the actual
attach still only takes effect for real once the notebook item is created in
that exact workspace (a real deploy, not a local rendering concern) — this
script does not call the Fabric API itself.
"""
import argparse
import json
import re
import sys

from render_pyspark import render as render_pyspark

from i18n import DEFAULT_LANGUAGE, LANGUAGES

_CELL_RE = re.compile(r"^# CELL \d+ — .+$", re.MULTILINE)


def _split_cells(script: str) -> list[str]:
    """Split the rendered PySpark script into one chunk per "# CELL n — ..." marker."""
    header, *chunks = _CELL_RE.split(script)
    markers = _CELL_RE.findall(script)
    cells = []
    if header.strip():
        cells.append(header.strip("\n"))
    for marker, chunk in zip(markers, chunks):
        cells.append((marker + chunk).strip("\n"))
    return cells


def _code_cell(source: str, tags: list[str] | None = None) -> dict:
    lines = source.split("\n")
    src = [line + "\n" for line in lines[:-1]] + ([lines[-1]] if lines[-1] else [])
    cell = {
        "cell_type": "code",
        "source": src,
        "outputs": [],
        "execution_count": None,
        "metadata": {},
    }
    if tags:
        cell["metadata"]["tags"] = tags
    return cell


def _markdown_cell(source: str) -> dict:
    lines = source.split("\n")
    src = [line + "\n" for line in lines[:-1]] + ([lines[-1]] if lines[-1] else [])
    return {"cell_type": "markdown", "source": src, "metadata": {}}


def render(table_name: str, start_year: int, end_year: int, fiscal_start_month: int,
           fiscal_year_basis: str, language: str = DEFAULT_LANGUAGE,
           workspace_name: str | None = None, lakehouse_name: str | None = None) -> str:
    script = render_pyspark(
        table_name=table_name,
        start_year=start_year,
        end_year=end_year,
        fiscal_start_month=fiscal_start_month,
        fiscal_year_basis=fiscal_year_basis,
        language=language,
    )
    chunks = _split_cells(script)
    # chunks[0] is the module docstring/header comment block; chunks[1] is
    # "# CELL 1 — parámetros" (the one Fabric parameterizes), the rest follow.
    header, params_cell, *rest_cells = chunks
    header_md = "\n".join(
        line[2:] if line.startswith("# ") else line.lstrip("#").strip()
        for line in header.splitlines()
        if line.strip("= ")
    )
    cells = [_markdown_cell(
        f"# DimTiempo\n\nDimensión de tiempo casi perfecta, generada por "
        f"dim-tiempo-casi-perfecta (idioma: {language}).\n\n{header_md}"
    )]
    cells.append(_code_cell(params_cell, tags=["parameters"]))
    for chunk in rest_cells:
        cells.append(_code_cell(chunk))

    metadata = {
        "kernelspec": {"display_name": "Synapse PySpark", "language": "Python", "name": "synapse_pyspark"},
        "language_info": {"name": "python"},
        "save_output": True,
        "spark_compute": {"compute_id": "/trident/default"},
        "synapse_widget": {"state": {}, "version": "0.1"},
    }
    if workspace_name and lakehouse_name:
        # Rellena la referencia de lakehouse por defecto; el ID real solo lo
        # conoce el workspace de destino, así que esto es una pista para
        # quien despliegue el notebook (p.ej. spark-authoring-cli), no una
        # resolución real — no hay llamada a la API de Fabric en este script.
        metadata["dependencies"] = {
            "lakehouse": {
                "default_lakehouse_name": lakehouse_name,
                "default_lakehouse_workspace_name": workspace_name,
            }
        }

    notebook = {
        "nbformat": 4,
        "nbformat_minor": 2,
        "cells": cells,
        "metadata": metadata,
    }
    return json.dumps(notebook, ensure_ascii=False, indent=1) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--table-name", default="DimFecha")
    parser.add_argument("--start-year", type=int, default=2019)
    parser.add_argument("--end-year", type=int, default=2028)
    parser.add_argument("--fiscal-start-month", type=int, default=6)
    parser.add_argument("--fiscal-year-basis", choices=["Start", "End"], default="End")
    parser.add_argument("--language", choices=sorted(LANGUAGES), default=DEFAULT_LANGUAGE,
                         help="idioma de 'Month Name'/'Day Name'/'Fiscal Month Name'")
    parser.add_argument("--workspace-name", default=None,
                         help="workspace de destino, solo para anotar el lakehouse por defecto en el notebook")
    parser.add_argument("--lakehouse-name", default=None,
                         help="lakehouse de destino, solo para anotar el lakehouse por defecto en el notebook")
    args = parser.parse_args()

    try:
        output = render(
            table_name=args.table_name,
            start_year=args.start_year,
            end_year=args.end_year,
            fiscal_start_month=args.fiscal_start_month,
            fiscal_year_basis=args.fiscal_year_basis,
            language=args.language,
            workspace_name=args.workspace_name,
            lakehouse_name=args.lakehouse_name,
        )
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

    sys.stdout.buffer.write(output.encode("utf-8"))


if __name__ == "__main__":
    main()
