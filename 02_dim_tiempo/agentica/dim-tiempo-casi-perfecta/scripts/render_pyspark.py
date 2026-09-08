#!/usr/bin/env python
"""Render the PySpark notebook script from templates/pyspark_dimfecha.py.j2.

Same rationale as render_dimension.py: don't hand-edit the notebook cells to
change the calendar parameters or the target table, call this script so the
same inputs always produce byte-identical output.

Usage:
    python render_pyspark.py --table-name DimFecha \
        --start-year 2019 --end-year 2028 \
        --fiscal-start-month 6 --fiscal-year-basis End

Prints the rendered script to stdout, ready to paste into a Fabric notebook
(one "# CELL" comment per cell) or to run through a Livy session for a real
test (see spark-consumption-cli).
"""
import argparse
import pathlib
import re
import sys

from jinja2 import Environment, FileSystemLoader, StrictUndefined

TEMPLATE_DIR = pathlib.Path(__file__).resolve().parent.parent / "templates"
# saveAsTable() accepts a bare name or a dotted schema.table (Fabric Lakehouse
# default schema is dbo); keep it to safe identifier characters so the
# rendered f-string / saveAsTable call can't be broken out of.
_TABLE_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$")


def render(table_name: str, start_year: int, end_year: int,
           fiscal_start_month: int, fiscal_year_basis: str) -> str:
    if fiscal_year_basis not in ("Start", "End"):
        raise ValueError('fiscal_year_basis must be "Start" or "End"')
    if not (1 <= fiscal_start_month <= 12):
        raise ValueError("fiscal_start_month must be between 1 and 12")
    if end_year < start_year:
        raise ValueError("end_year must be >= start_year")
    if not _TABLE_NAME_RE.match(table_name):
        raise ValueError(
            f"table_name={table_name!r} is not a plain identifier or dotted schema.table "
            "(letters/digits/underscore, not starting with a digit)"
        )

    env = Environment(
        loader=FileSystemLoader(str(TEMPLATE_DIR)),
        undefined=StrictUndefined,
        keep_trailing_newline=True,
    )
    template = env.get_template("pyspark_dimfecha.py.j2")
    return template.render(
        table_name=table_name,
        start_year=start_year,
        end_year=end_year,
        fiscal_start_month=fiscal_start_month,
        fiscal_year_basis=fiscal_year_basis,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--table-name", default="DimFecha")
    parser.add_argument("--start-year", type=int, default=2019)
    parser.add_argument("--end-year", type=int, default=2028)
    parser.add_argument("--fiscal-start-month", type=int, default=6)
    parser.add_argument("--fiscal-year-basis", choices=["Start", "End"], default="End")
    args = parser.parse_args()

    try:
        output = render(
            table_name=args.table_name,
            start_year=args.start_year,
            end_year=args.end_year,
            fiscal_start_month=args.fiscal_start_month,
            fiscal_year_basis=args.fiscal_year_basis,
        )
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

    sys.stdout.buffer.write(output.encode("utf-8"))


if __name__ == "__main__":
    main()
