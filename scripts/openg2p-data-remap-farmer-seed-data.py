#!/usr/bin/env python3
"""Remap farmer db-seed JSON legacy ids (i0001, h001) to openg2p-data UUIDs."""

from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from farmer_seed_enum_normalization import normalize_farmer_extra  # noqa: E402

INDIVIDUAL_LEGACY = re.compile(r"^i(\d{4})$")
HOUSEHOLD_LEGACY = re.compile(r"^h(\d{3})$")

REMAP_FIELDS = ("internal_record_id", "link_internal_record_id", "member_individual_id")


def _legacy_individual_id(functional_record_id: str) -> str:
    seq = int(functional_record_id.split("-")[1])
    return f"i{seq:04d}"


def _legacy_household_id(functional_record_id: str) -> str:
    seq = int(functional_record_id.split("-")[1])
    return f"h{seq:03d}"


def _load_json_array(path: Path) -> list[dict]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError(f"Expected JSON array in {path}")
    return rows


def _build_id_maps(data_dir: Path) -> tuple[dict[str, str], dict[str, str]]:
    individuals = _load_json_array(data_dir / "demography" / "individuals.json")
    households = _load_json_array(data_dir / "demography" / "households.json")

    individual_map = {
        _legacy_individual_id(row["functional_record_id"]): row["internal_record_id"]
        for row in individuals
    }
    household_map = {
        _legacy_household_id(row["functional_record_id"]): row["internal_record_id"]
        for row in households
    }
    return individual_map, household_map


def _remap_value(value: object, individual_map: dict[str, str], household_map: dict[str, str]) -> object:
    if not isinstance(value, str):
        return value
    if INDIVIDUAL_LEGACY.match(value):
        mapped = individual_map.get(value)
        if mapped is None:
            raise KeyError(f"No individual UUID for legacy id {value}")
        return mapped
    if HOUSEHOLD_LEGACY.match(value):
        mapped = household_map.get(value)
        if mapped is None:
            raise KeyError(f"No household UUID for legacy id {value}")
        return mapped
    return value


def _remap_record(
    record: dict,
    individual_map: dict[str, str],
    household_map: dict[str, str],
    *,
    remap_internal_record_id: bool,
) -> dict:
    remapped = dict(record)
    for field in REMAP_FIELDS:
        if field not in remapped:
            continue
        if field == "internal_record_id" and not remap_internal_record_id:
            continue
        remapped[field] = _remap_value(remapped[field], individual_map, household_map)
    return remapped


def remap_seed_data(
    data_dir: Path,
    source_seed_dir: Path,
    output_seed_dir: Path,
) -> None:
    individual_map, household_map = _build_id_maps(data_dir)

    if output_seed_dir.exists():
        shutil.rmtree(output_seed_dir)
    output_seed_dir.mkdir(parents=True)

    for seed_file in sorted(source_seed_dir.glob("*.json")):
        rows = _load_json_array(seed_file)
        remap_internal = seed_file.name == "farmers.json"
        remapped_rows = [
            _remap_record(row, individual_map, household_map, remap_internal_record_id=remap_internal)
            for row in rows
        ]
        if seed_file.name == "farmers.json":
            normalized_rows = []
            changed = 0
            for row in remapped_rows:
                fixed = normalize_farmer_extra(row)
                if fixed != row:
                    changed += 1
                normalized_rows.append(fixed)
            remapped_rows = normalized_rows
            if changed:
                print(
                    f"[openg2p-data]   normalized source_of_income on "
                    f"{changed} farmer seed row(s)",
                    file=sys.stderr,
                )
        out_path = output_seed_dir / seed_file.name
        out_path.write_text(json.dumps(remapped_rows, indent=2) + "\n", encoding="utf-8")

    print(
        f"[openg2p-data] Remapped farmer seed data "
        f"({len(individual_map)} individuals, {len(household_map)} households) "
        f"-> {output_seed_dir}"
    )


def main() -> None:
    if len(sys.argv) < 4:
        print(
            "Usage: openg2p-data-remap-farmer-seed-data.py "
            "<openg2p-data-dir> <source-seed-dir> <output-seed-dir>",
            file=sys.stderr,
        )
        sys.exit(1)

    data_dir = Path(sys.argv[1]).resolve()
    source_seed_dir = Path(sys.argv[2]).resolve()
    output_seed_dir = Path(sys.argv[3]).resolve()

    if not (data_dir / "demography" / "individuals.json").is_file():
        print(f"[openg2p-data] Missing demography JSON under {data_dir}", file=sys.stderr)
        sys.exit(1)
    if not source_seed_dir.is_dir():
        print(f"[openg2p-data] Missing source seed dir: {source_seed_dir}", file=sys.stderr)
        sys.exit(1)

    remap_seed_data(data_dir, source_seed_dir, output_seed_dir)


if __name__ == "__main__":
    main()
