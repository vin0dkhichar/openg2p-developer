#!/usr/bin/env python3
"""Build geo/geo.csv from openg2p-data geo/*.json for load_geo_data.py."""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

GEO_COLUMNS = ["country", "region", "district", "ward", "village"]
LEVEL_FILES = [
    "level-0-country.json",
    "level-1-regions.json",
    "level-2-districts.json",
    "level-3-wards.json",
    "level-4-villages.json",
]


def _load_json(path: Path) -> list[dict]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError(f"Expected JSON array in {path}")
    return rows


def _build_index(data_dir: Path) -> tuple[dict[str, dict], dict[str, str]]:
    by_id: dict[str, dict] = {}
    for filename in LEVEL_FILES:
        path = data_dir / filename
        if not path.is_file():
            raise FileNotFoundError(path)
        for row in _load_json(path):
            by_id[row["level_value_id"]] = row

    level_id_to_column = {}
    for row in _load_json(data_dir / "levels.json"):
        mnemonic = row["level_mnemonic"]
        if mnemonic in GEO_COLUMNS:
            level_id_to_column[row["level_id"]] = mnemonic

    return by_id, level_id_to_column


def _path_for_node(node_id: str, by_id: dict[str, dict], level_id_to_column: dict[str, str]) -> dict[str, str]:
    chain: list[tuple[str, str]] = []
    current = by_id.get(node_id)
    while current is not None:
        column = level_id_to_column.get(current["level_id"])
        if column:
            chain.append((column, current["level_value_mnemonic"]))
        parent_id = current.get("parent_level_value_id")
        current = by_id.get(parent_id) if parent_id else None
    chain.reverse()
    return dict(chain)


def main() -> None:
    data_root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    geo_dir = data_root / "geo"
    output = geo_dir / "geo.csv"

    if output.is_file():
        print("[openg2p-data] geo.csv already present.")
        return

    by_id, level_id_to_column = _build_index(geo_dir)
    villages = _load_json(geo_dir / "level-4-villages.json")

    rows: list[dict[str, str]] = []
    for village in villages:
        path = _path_for_node(village["level_value_id"], by_id, level_id_to_column)
        if set(path.keys()) != set(GEO_COLUMNS):
            continue
        rows.append({column: path[column] for column in GEO_COLUMNS})

    if not rows:
        print("[openg2p-data] No complete geo rows generated.", file=sys.stderr)
        sys.exit(1)

    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=GEO_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)

    print(f"[openg2p-data] Wrote {len(rows)} rows to {output}")


if __name__ == "__main__":
    main()
