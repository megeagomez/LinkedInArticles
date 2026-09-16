#!/usr/bin/env python
"""Render the T-SQL CREATE TABLE script from templates/tsql_dimfecha.sql.j2.

Same rationale as render_dimension.py: don't hand-edit SQL text to change the
calendar parameters or the target table, call this script so the same inputs
always produce byte-identical output.

Usage:
    python render_tsql.py --schema-name dbo --table-name DimFecha \
        --start-year 2019 --end-year 2028 \
        --fiscal-start-month 6 --fiscal-year-basis End --target fabric

Prints the rendered T-SQL to stdout, ready to run against a Fabric Data
Warehouse (--target fabric, default; or a skill that talks to it, e.g.
sqldw-authoring-cli) or a plain SQL Server instance, on-prem or Azure SQL
(--target sqlserver). The two targets materialize the table differently:
Fabric Warehouse only supports CTAS (CREATE TABLE ... AS SELECT), while SQL
Server only supports SELECT ... INTO — passing the wrong target for your
actual engine fails with "Incorrect syntax near CREATE" (fabric SQL sent to
sqlserver) or silently does nothing useful the other way around.
"""
import argparse
import pathlib
import re
import sys

from jinja2 import Environment, FileSystemLoader, StrictUndefined

from i18n import DEFAULT_LANGUAGE, LANGUAGES, get_language

TEMPLATE_DIR = pathlib.Path(__file__).resolve().parent.parent / "templates"
_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def render(schema_name: str, table_name: str, start_year: int, end_year: int,
           fiscal_start_month: int, fiscal_year_basis: str, target: str = "fabric",
           language: str = DEFAULT_LANGUAGE) -> str:
    if target not in ("fabric", "sqlserver"):
        raise ValueError('target must be "fabric" or "sqlserver"')
    if fiscal_year_basis not in ("Start", "End"):
        raise ValueError('fiscal_year_basis must be "Start" or "End"')
    if not (1 <= fiscal_start_month <= 12):
        raise ValueError("fiscal_start_month must be between 1 and 12")
    if end_year < start_year:
        raise ValueError("end_year must be >= start_year")
    for name, value in (("schema_name", schema_name), ("table_name", table_name)):
        if not _IDENTIFIER_RE.match(value):
            raise ValueError(
                f"{name}={value!r} is not a plain SQL identifier (letters/digits/underscore, "
                "not starting with a digit) — use [brackets] yourself in the target script if "
                "you need something fancier, this generator won't build injectable SQL for you"
            )
    lang = get_language(language)

    env = Environment(
        loader=FileSystemLoader(str(TEMPLATE_DIR)),
        undefined=StrictUndefined,
        keep_trailing_newline=True,
    )
    template = env.get_template("tsql_dimfecha.sql.j2")
    return template.render(
        schema_name=schema_name,
        table_name=table_name,
        start_year=start_year,
        end_year=end_year,
        fiscal_start_month=fiscal_start_month,
        fiscal_year_basis=fiscal_year_basis,
        target=target,
        months=lang["months"],
        days=lang["days"],
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema-name", default="dbo")
    parser.add_argument("--table-name", default="DimFecha")
    parser.add_argument("--start-year", type=int, default=2019)
    parser.add_argument("--end-year", type=int, default=2028)
    parser.add_argument("--fiscal-start-month", type=int, default=6)
    parser.add_argument("--fiscal-year-basis", choices=["Start", "End"], default="End")
    parser.add_argument("--target", choices=["fabric", "sqlserver"], default="fabric")
    parser.add_argument("--language", choices=sorted(LANGUAGES), default=DEFAULT_LANGUAGE,
                         help="idioma de 'Month Name'/'Day Name'/'Fiscal Month Name'")
    args = parser.parse_args()

    try:
        output = render(
            schema_name=args.schema_name,
            table_name=args.table_name,
            start_year=args.start_year,
            end_year=args.end_year,
            fiscal_start_month=args.fiscal_start_month,
            fiscal_year_basis=args.fiscal_year_basis,
            target=args.target,
            language=args.language,
        )
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

    sys.stdout.buffer.write(output.encode("utf-8"))


if __name__ == "__main__":
    main()
