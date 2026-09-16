#!/usr/bin/env python
"""Render the time-dimension TMDL createOrReplace script from templates/dimension.tmdl.j2.

Deterministic by design: the skill should never hand-edit TMDL text to change
the table name or calendar parameters. It calls this script instead, so the
same inputs always produce byte-identical output.

Usage:
    python render_dimension.py --table-name Fecha --start-year 2019 \
        --end-year 2028 --fiscal-start-month 6 --fiscal-year-basis End

Prints the rendered TMDL to stdout. Redirect to a file, or pipe straight into
whatever executes the TMDL script (Tabular Editor 3's TMDL Script pane, or a
skill that talks to Power BI Desktop / Fabric).
"""
import argparse
import pathlib
import sys

from jinja2 import Environment, FileSystemLoader, StrictUndefined

from i18n import DEFAULT_LANGUAGE, LANGUAGES, get_language

TEMPLATE_DIR = pathlib.Path(__file__).resolve().parent.parent / "templates"


def render(table_name: str, start_year: int, end_year: int,
           fiscal_start_month: int, fiscal_year_basis: str,
           language: str = DEFAULT_LANGUAGE) -> str:
    if fiscal_year_basis not in ("Start", "End"):
        raise ValueError('fiscal_year_basis must be "Start" or "End"')
    if not (1 <= fiscal_start_month <= 12):
        raise ValueError("fiscal_start_month must be between 1 and 12")
    if end_year < start_year:
        raise ValueError("end_year must be >= start_year")
    lang = get_language(language)

    env = Environment(
        loader=FileSystemLoader(str(TEMPLATE_DIR)),
        undefined=StrictUndefined,
        keep_trailing_newline=True,
    )
    template = env.get_template("dimension.tmdl.j2")
    return template.render(
        table_name=table_name,
        start_year=start_year,
        end_year=end_year,
        fiscal_start_month=fiscal_start_month,
        fiscal_year_basis=fiscal_year_basis,
        months=lang["months"],
        days=lang["days"],
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--table-name", default="Fecha")
    parser.add_argument("--start-year", type=int, default=2019)
    parser.add_argument("--end-year", type=int, default=2028)
    parser.add_argument("--fiscal-start-month", type=int, default=6)
    parser.add_argument("--fiscal-year-basis", choices=["Start", "End"], default="End")
    parser.add_argument("--language", choices=sorted(LANGUAGES), default=DEFAULT_LANGUAGE,
                         help="idioma de 'Month Name'/'Day Name'/'Fiscal Month Name'")
    args = parser.parse_args()

    try:
        output = render(
            table_name=args.table_name,
            start_year=args.start_year,
            end_year=args.end_year,
            fiscal_start_month=args.fiscal_start_month,
            fiscal_year_basis=args.fiscal_year_basis,
            language=args.language,
        )
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

    sys.stdout.buffer.write(output.encode("utf-8"))


if __name__ == "__main__":
    main()
