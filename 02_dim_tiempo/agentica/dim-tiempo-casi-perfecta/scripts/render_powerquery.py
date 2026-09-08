#!/usr/bin/env python
"""Render the standalone Power Query M script from templates/powerquery_m.pq.j2.

Same rationale as render_dimension.py: don't hand-edit M text to change the
calendar parameters, call this script so the same inputs always produce
byte-identical output.

Usage:
    python render_powerquery.py --start-year 2019 --end-year 2028 \
        --fiscal-start-month 6 --fiscal-year-basis End

Prints the rendered M query to stdout, ready to paste into Power Query's
Advanced Editor (Power BI Desktop, Dataflow Gen2, Excel) or to hand to
dataflows-authoring-cli's preview loop for a real test.
"""
import argparse
import pathlib
import sys

from jinja2 import Environment, FileSystemLoader, StrictUndefined

TEMPLATE_DIR = pathlib.Path(__file__).resolve().parent.parent / "templates"


def render(start_year: int, end_year: int, fiscal_start_month: int, fiscal_year_basis: str) -> str:
    if fiscal_year_basis not in ("Start", "End"):
        raise ValueError('fiscal_year_basis must be "Start" or "End"')
    if not (1 <= fiscal_start_month <= 12):
        raise ValueError("fiscal_start_month must be between 1 and 12")
    if end_year < start_year:
        raise ValueError("end_year must be >= start_year")

    env = Environment(
        loader=FileSystemLoader(str(TEMPLATE_DIR)),
        undefined=StrictUndefined,
        keep_trailing_newline=True,
    )
    template = env.get_template("powerquery_m.pq.j2")
    return template.render(
        start_year=start_year,
        end_year=end_year,
        fiscal_start_month=fiscal_start_month,
        fiscal_year_basis=fiscal_year_basis,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start-year", type=int, default=2019)
    parser.add_argument("--end-year", type=int, default=2028)
    parser.add_argument("--fiscal-start-month", type=int, default=6)
    parser.add_argument("--fiscal-year-basis", choices=["Start", "End"], default="End")
    args = parser.parse_args()

    try:
        output = render(
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
