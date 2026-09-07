#!/usr/bin/env python
"""Render a createOrReplace TMDL script for one active + N inactive
role-playing relationships between a fact table and the time dimension.

Deterministic by design, same reasoning as render_dimension.py: the skill
builds a Python list of relationship specs from what the user asked for, and
this script turns that into TMDL text — it never free-hands TMDL.

Usage (as a library, called from the skill's workflow):

    from render_relationships import render, Relationship
    tmdl = render([
        Relationship("Ventas", "Fecha de Venta", "Fecha", "Date", is_active=True),
        Relationship("Ventas", "Fecha Entrega",  "Fecha", "Date", is_active=False),
        Relationship("Ventas", "Fecha Envio",    "Fecha", "Date", is_active=False),
        Relationship("Ventas", "Fecha Factura",  "Fecha", "Date", is_active=False),
    ])

Or from the CLI, one relationship per --rel argument:

    python render_relationships.py \
        --rel "Ventas|Fecha de Venta|Fecha|Date|active" \
        --rel "Ventas|Fecha Entrega|Fecha|Date|inactive" \
        --rel "Ventas|Fecha Envio|Fecha|Date|inactive" \
        --rel "Ventas|Fecha Factura|Fecha|Date|inactive"

Exactly one relationship per (fact_table, dimension_table) pair must be
active — that's the rule that makes a role-playing dimension work: Power BI
auto-propagates filters only through the active relationship, and the
inactive ones are switched on per-measure with USERELATIONSHIP(). This
script enforces exactly-one-active per (from_table, to_table) pair and
refuses to render otherwise, so a mistake here fails loudly instead of
silently creating a model where two "Date" relationships fight for
auto-filtering.
"""
import argparse
import pathlib
import sys
from collections import Counter
from dataclasses import dataclass

from jinja2 import Environment, FileSystemLoader, StrictUndefined

TEMPLATE_DIR = pathlib.Path(__file__).resolve().parent.parent / "templates"


@dataclass
class Relationship:
    from_table: str
    from_column: str
    to_table: str
    to_column: str
    is_active: bool

    @property
    def name(self) -> str:
        # Human-readable relationship identifier. TMDL relationship "names"
        # are usually the object's internal GUID in real exports; using a
        # readable token instead is unverified — see references/relationship-tmdl.md.
        return f"{self.from_table}_{self.from_column}_{self.to_table}".replace(" ", "")


def render(relationships: list[Relationship]) -> str:
    if not relationships:
        raise ValueError("need at least one relationship")

    active_counts = Counter(
        (r.from_table, r.to_table) for r in relationships if r.is_active
    )
    pairs = {(r.from_table, r.to_table) for r in relationships}
    for pair in pairs:
        if active_counts[pair] != 1:
            raise ValueError(
                f"{pair[0]} -> {pair[1]} must have exactly one active relationship, "
                f"found {active_counts[pair]}. Role-playing dimensions need exactly "
                "one active path; the rest stay inactive and get switched on with "
                "USERELATIONSHIP() inside the measures that need that date."
            )

    env = Environment(
        loader=FileSystemLoader(str(TEMPLATE_DIR)),
        undefined=StrictUndefined,
        keep_trailing_newline=True,
        trim_blocks=True,
    )
    template = env.get_template("relationships.tmdl.j2")
    return template.render(relationships=relationships)


def _parse_rel(spec: str) -> Relationship:
    parts = spec.split("|")
    if len(parts) != 5:
        raise ValueError(
            f"--rel expects 'FromTable|FromColumn|ToTable|ToColumn|active|inactive', got: {spec}"
        )
    from_table, from_column, to_table, to_column, state = parts
    if state not in ("active", "inactive"):
        raise ValueError(f"last field must be 'active' or 'inactive', got: {state}")
    return Relationship(from_table, from_column, to_table, to_column, state == "active")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--rel", action="append", required=True,
        help="FromTable|FromColumn|ToTable|ToColumn|active|inactive (repeatable)",
    )
    args = parser.parse_args()

    try:
        relationships = [_parse_rel(r) for r in args.rel]
        output = render(relationships)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

    sys.stdout.buffer.write(output.encode("utf-8"))


if __name__ == "__main__":
    main()
