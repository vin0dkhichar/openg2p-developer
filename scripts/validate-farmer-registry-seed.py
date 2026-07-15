#!/usr/bin/env python3
"""Audit farmer registry seed data and DB rows against extension enums/lookups."""

from __future__ import annotations

import csv
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

import psycopg2

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
from farmer_seed_enum_normalization import VALID_SOURCE_OF_INCOME  # noqa: E402

WORKSPACE = Path(
    os.environ.get(
        "OPENG2P_WORKSPACE",
        str(ROOT.parent / "openg2p-workspace"),
    )
).resolve()
EXTENSION = WORKSPACE / "farmer-registry" / "farmer-extension"
ENUMS_FILE = (
    EXTENSION
    / "src/openg2p_registry_farmer_extension/register_domain/models/enums.py"
)
LOOKUP_SQL = (
    EXTENSION
    / "src/openg2p_registry_farmer_extension/meta_data/lookup-data/g2p_attribute_values.sql"
)
SEED_DIR = Path(
    os.environ.get(
        "FARMER_SEED_DATA_DIR",
        str(ROOT / "generated/farmer-registry/seed-data-remapped"),
    )
).resolve()
DATA_DIR = Path(
    os.environ.get(
        "OPENG2P_DATA_DIR",
        str(WORKSPACE / "openg2p-data"),
    )
).resolve()

# field -> pydantic enum class name in enums.py (or "lookup:ATTRIBUTE_ID")
FIELD_RULES: dict[str, str] = {
    "source_of_income": "SourceOfIncomeEnum",
    "disability_type": "DisabilityTypeEnum",
    "disability_severity": "DisabilitySeverityEnum",
    "education_level": "EducationalLevelEnum",
    "land_ownership_type": "LandOwnershipTypeEnum",
    "unit": "LandSizeUnitEnum",
    "current_land_use": "CurrentLandUseEnum",
    "farming_type": "FarmingTypeEnum",
    "end_use": "CropEndUseEnum",
    "livestock_system": "LivestockSystemEnum",
    "farmer_cluster_role": "FarmerClusterRoleEnum",
    "commodity": "lookup:CROP_COMMODITY",
    "season": "lookup:CROP_SEASON",
    "livestock_type": "lookup:LIVESTOCK_TYPE",
    "breed": "lookup:LIVESTOCK_BREED",
    "water_source": "lookup:WATER_SOURCE",
    "means_of_acquisition": "lookup:MEANS_OF_ACQUISITION",
    "soil_fertility": "lookup:SOIL_FERTILITY",
}

DB_TABLE_FIELDS: dict[str, list[str]] = {
    "g2p_register_farmers": [
        "source_of_income",
        "disability_type",
        "disability_severity",
        "education_level",
    ],
    "g2p_register_lands": [
        "land_ownership_type",
        "unit",
        "current_land_use",
        "farming_type",
        "means_of_acquisition",
        "soil_fertility",
    ],
    "g2p_register_crops": ["commodity", "season", "end_use"],
    "g2p_register_livestocks": ["livestock_type", "breed", "livestock_system"],
    "g2p_register_farm_inputs": ["water_source"],
    "g2p_register_membership_details": ["farmer_cluster_role"],
}


def _parse_enums(path: Path) -> dict[str, set[str]]:
    text = path.read_text(encoding="utf-8")
    enums: dict[str, set[str]] = {}
    current: str | None = None
    for line in text.splitlines():
        class_match = re.match(r"class (\w+)\(StrEnum\):", line)
        if class_match:
            current = class_match.group(1)
            enums[current] = set()
            continue
        if current and "=" in line and not line.strip().startswith("#"):
            value_match = re.match(r"\s+(\w+)\s*=\s*\"([^\"]+)\"", line)
            if value_match:
                enums[current].add(value_match.group(2))
    return enums


def _parse_lookup_values(path: Path) -> dict[str, set[str]]:
    text = path.read_text(encoding="utf-8")
    lookups: dict[str, set[str]] = defaultdict(set)
    row_re = re.compile(
        r"\('[^']+','([^']+)','([^']+)','[^']*',[^,]*,\d+\)"
    )
    for attribute_id, value_code in row_re.findall(text):
        lookups[attribute_id].add(value_code)
    return dict(lookups)


def _allowed_values(field: str, enums: dict[str, set[str]], lookups: dict[str, set[str]]) -> set[str] | None:
    rule = FIELD_RULES.get(field)
    if not rule:
        return None
    if rule.startswith("lookup:"):
        return lookups.get(rule.split(":", 1)[1], set())
    return enums.get(rule, set())


def _check_records(
    label: str,
    records: list[dict],
    enums: dict[str, set[str]],
    lookups: dict[str, set[str]],
) -> list[str]:
    issues: list[str] = []
    for index, record in enumerate(records):
        for field, rule in FIELD_RULES.items():
            if field not in record:
                continue
            value = record.get(field)
            if value is None or value == "":
                continue
            allowed = _allowed_values(field, enums, lookups)
            if allowed is None:
                continue
            if value not in allowed:
                issues.append(
                    f"{label}[{index}] {field}={value!r} not in {sorted(allowed)}"
                )
    return issues


def _load_json_array(path: Path) -> list[dict]:
    if not path.is_file():
        return []
    rows = json.loads(path.read_text(encoding="utf-8"))
    return rows if isinstance(rows, list) else []


def _check_seed_files(enums: dict[str, set[str]], lookups: dict[str, set[str]]) -> list[str]:
    issues: list[str] = []
    if not SEED_DIR.is_dir():
        return [f"Missing remapped seed dir: {SEED_DIR}"]

    file_map = {
        "farmers.json": None,
        "lands.json": None,
        "crops.json": None,
        "livestocks.json": None,
        "farm_inputs.json": None,
        "membership_details.json": None,
    }
    for name in file_map:
        path = SEED_DIR / name
        rows = _load_json_array(path)
        issues.extend(_check_records(f"seed:{name}", rows, enums, lookups))

    individuals_csv = DATA_DIR / "demography" / "individuals.csv"
    if individuals_csv.is_file():
        with individuals_csv.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))
        issues.extend(_check_records("csv:individuals", rows, enums, lookups))
    return issues


def _check_database(enums: dict[str, set[str]], lookups: dict[str, set[str]]) -> list[str]:
    issues: list[str] = []
    conn = psycopg2.connect(
        host=os.environ["PGHOST"],
        port=os.environ.get("PGPORT", "5432"),
        dbname=os.environ["PGDATABASE"],
        user=os.environ["PGUSER"],
        password=os.environ["PGPASSWORD"],
    )
    try:
        with conn.cursor() as cur:
            for table, fields in DB_TABLE_FIELDS.items():
                cur.execute(
                    """
                    SELECT EXISTS (
                      SELECT 1 FROM information_schema.tables
                      WHERE table_schema = 'public' AND table_name = %s
                    )
                    """,
                    (table,),
                )
                if not cur.fetchone()[0]:
                    continue
                for field in fields:
                    allowed = _allowed_values(field, enums, lookups)
                    if not allowed:
                        continue
                    cur.execute(
                        f"""
                        SELECT "{field}", COUNT(*)
                        FROM "public"."{table}"
                        WHERE "{field}" IS NOT NULL AND "{field}" <> ''
                        GROUP BY 1
                        """,
                    )
                    for value, count in cur.fetchall():
                        if value not in allowed:
                            issues.append(
                                f"db:{table}.{field}={value!r} ({count} rows) not in schema"
                            )

            cur.execute(
                """
                SELECT EXISTS (
                  SELECT 1 FROM information_schema.tables
                  WHERE table_schema = 'public'
                    AND table_name = 'g2p_register_change_request_payloads'
                )
                """
            )
            if cur.fetchone()[0]:
                cur.execute(
                    "SELECT change_request_id, change_payload "
                    'FROM "public"."g2p_register_change_request_payloads"'
                )
                for change_request_id, payload in cur.fetchall():
                    if not payload:
                        continue
                    if isinstance(payload, str):
                        payload = json.loads(payload)
                    payload_issues = _check_records(
                        f"change_request:{change_request_id}",
                        payload if isinstance(payload, list) else [payload],
                        enums,
                        lookups,
                    )
                    issues.extend(payload_issues)

            cur.execute('SELECT COUNT(*) FROM "public"."g2p_register_farmers"')
            farmer_count = cur.fetchone()[0]
            cur.execute(
                """
                SELECT COUNT(*)
                FROM "public"."g2p_register_lands" l
                LEFT JOIN "public"."g2p_register_farmers" f
                  ON f.internal_record_id = l.link_internal_record_id
                WHERE l.link_internal_record_id IS NOT NULL AND f.internal_record_id IS NULL
                """
            )
            orphan_lands = cur.fetchone()[0]
            if orphan_lands:
                issues.append(
                    f"db:orphan land rows with missing farmer link: {orphan_lands}"
                )
    finally:
        conn.close()
    return issues


def _check_referential_seed() -> list[str]:
    issues: list[str] = []
    farmers = {r["internal_record_id"] for r in _load_json_array(SEED_DIR / "farmers.json")}
    lands = {r["internal_record_id"] for r in _load_json_array(SEED_DIR / "lands.json")}
    individual_ids: set[str] = set()
    individuals_csv = DATA_DIR / "demography" / "individuals.csv"
    if individuals_csv.is_file():
        with individuals_csv.open(newline="", encoding="utf-8") as handle:
            individual_ids = {row["internal_record_id"] for row in csv.DictReader(handle)}
        missing_farmer_extras = sorted(individual_ids - farmers)
        if missing_farmer_extras:
            issues.append(
                f"seed: {len(missing_farmer_extras)} individuals missing farmers.json extras"
            )

    for index, row in enumerate(_load_json_array(SEED_DIR / "lands.json")):
        link = row.get("link_internal_record_id")
        if link and link not in farmers and link not in individual_ids:
            issues.append(f"seed:lands.json[{index}] orphan farmer link={link}")

    land_linked_tables = ("crops.json", "livestocks.json", "farm_inputs.json")
    for fname in land_linked_tables:
        for index, row in enumerate(_load_json_array(SEED_DIR / fname)):
            link = row.get("link_internal_record_id")
            if link and link not in lands:
                issues.append(f"seed:{fname}[{index}] orphan land link={link}")

    for index, row in enumerate(_load_json_array(SEED_DIR / "membership_details.json")):
        link = row.get("link_internal_record_id")
        if link and link not in farmers and link not in individual_ids:
            issues.append(f"seed:membership_details.json[{index}] orphan farmer link={link}")
    return issues


def main() -> None:
    enums = _parse_enums(ENUMS_FILE)
    lookups = _parse_lookup_values(LOOKUP_SQL)

    print("[validate-farmer-seed] Checking remapped seed + DB against extension schemas ...")
    issues: list[str] = []
    issues.extend(_check_seed_files(enums, lookups))
    issues.extend(_check_referential_seed())

    if all(os.environ.get(key) for key in ("PGHOST", "PGDATABASE", "PGUSER", "PGPASSWORD")):
        issues.extend(_check_database(enums, lookups))
    else:
        print("[validate-farmer-seed] Skipping DB checks (PG* env not set).", file=sys.stderr)

    if issues:
        print(f"[validate-farmer-seed] FAILED: {len(issues)} issue(s)")
        for issue in issues[:50]:
            print(f"  - {issue}")
        if len(issues) > 50:
            print(f"  ... and {len(issues) - 50} more")
        sys.exit(1)

    print("[validate-farmer-seed] OK — no enum/lookup validation issues found.")
    print(
        "[validate-farmer-seed] source_of_income allowed:",
        ", ".join(sorted(VALID_SOURCE_OF_INCOME)),
    )


if __name__ == "__main__":
    main()
