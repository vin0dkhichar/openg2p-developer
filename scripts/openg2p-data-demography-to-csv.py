#!/usr/bin/env python3
"""Convert openg2p-data demography JSON files to CSV for NSR db-seed loader."""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

INDIVIDUAL_JSON_COLUMNS = {"phone_numbers", "geo_hierarchy_json"}
HOUSEHOLD_JSON_COLUMNS = {"member_ids", "geo_hierarchy_json"}


def _load_rows(path: Path) -> list[dict]:
    if not path.is_file():
        print(f"[openg2p-data] Missing file: {path}", file=sys.stderr)
        sys.exit(1)
    rows = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        print(f"[openg2p-data] Expected JSON array in {path}", file=sys.stderr)
        sys.exit(1)
    return rows


def _write_csv(path: Path, rows: list[dict], json_columns: set[str]) -> None:
    if not rows:
        print(f"[openg2p-data] No rows for {path.name}; skipping.", file=sys.stderr)
        return

    fieldnames: list[str] = []
    seen: set[str] = set()
    for row in rows:
        for key in row:
            if key not in seen:
                seen.add(key)
                fieldnames.append(key)

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            out = {}
            for key, value in row.items():
                if value is None:
                    out[key] = ""
                elif key in json_columns and not isinstance(value, str):
                    out[key] = json.dumps(value, separators=(",", ":"))
                else:
                    out[key] = value
            writer.writerow(out)

    print(f"[openg2p-data] Wrote {len(rows)} rows to {path}")


def main() -> None:
    data_dir = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve() / "demography"
    individuals_json = data_dir / "individuals.json"
    households_json = data_dir / "households.json"
    individuals_csv = data_dir / "individuals.csv"
    households_csv = data_dir / "households.csv"

    if individuals_csv.is_file() and households_csv.is_file():
        print("[openg2p-data] Demography CSV files already present.")
        return

    if not individuals_json.is_file() or not households_json.is_file():
        print(
            "[openg2p-data] Expected individuals.json and households.json under "
            f"{data_dir}",
            file=sys.stderr,
        )
        sys.exit(1)

    _write_csv(individuals_csv, _load_rows(individuals_json), INDIVIDUAL_JSON_COLUMNS)
    _write_csv(households_csv, _load_rows(households_json), HOUSEHOLD_JSON_COLUMNS)


if __name__ == "__main__":
    main()
