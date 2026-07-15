#!/usr/bin/env python3
"""Align seeded farmer registry rows with current Pydantic enum values."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import psycopg2
from psycopg2.extras import Json

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from farmer_seed_enum_normalization import (  # noqa: E402
    SOURCE_OF_INCOME_LEGACY,
    normalize_json_tree_if_changed,
    normalize_source_of_income_fields,
)


def _connect() -> psycopg2.extensions.connection:
    return psycopg2.connect(
        host=os.environ["PGHOST"],
        port=os.environ.get("PGPORT", "5432"),
        dbname=os.environ["PGDATABASE"],
        user=os.environ["PGUSER"],
        password=os.environ["PGPASSWORD"],
    )


def _fix_farmers(cur) -> int:
    legacy_values = tuple(SOURCE_OF_INCOME_LEGACY.keys())
    cur.execute(
        """
        SELECT internal_record_id, source_of_income, source_of_income_other
        FROM "public"."g2p_register_farmers"
        WHERE source_of_income = ANY(%s)
           OR (
             source_of_income IS NOT NULL
             AND source_of_income NOT IN (
               'CROP_PRODUCTION', 'LIVESTOCK_PRODUCTION',
               'GOVERNMENT_NGO_SUPPORT', 'OTHERS'
             )
           )
        """,
        (list(legacy_values),),
    )
    rows = cur.fetchall()
    updated = 0
    for internal_record_id, source_of_income, source_of_income_other in rows:
        normalized = normalize_source_of_income_fields(
            {
                "source_of_income": source_of_income,
                "source_of_income_other": source_of_income_other,
            }
        )
        cur.execute(
            """
            UPDATE "public"."g2p_register_farmers"
            SET source_of_income = %s, source_of_income_other = %s
            WHERE internal_record_id = %s
            """,
            (
                normalized.get("source_of_income"),
                normalized.get("source_of_income_other"),
                internal_record_id,
            ),
        )
        updated += 1
    return updated


def _fix_change_request_payloads(cur) -> int:
    cur.execute(
        """
        SELECT EXISTS (
          SELECT 1 FROM information_schema.tables
          WHERE table_schema = 'public'
            AND table_name = 'g2p_register_change_request_payloads'
        )
        """
    )
    if not cur.fetchone()[0]:
        return 0

    cur.execute(
        """
        SELECT change_request_id, change_payload
        FROM "public"."g2p_register_change_request_payloads"
        """
    )
    updated = 0
    for change_request_id, payload in cur.fetchall():
        if payload is None:
            continue
        if isinstance(payload, str):
            payload = json.loads(payload)
        normalized, changed = normalize_json_tree_if_changed(payload)
        if not changed:
            continue
        cur.execute(
            """
            UPDATE "public"."g2p_register_change_request_payloads"
            SET change_payload = %s
            WHERE change_request_id = %s
            """,
            (Json(normalized), change_request_id),
        )
        updated += 1
    return updated


def main() -> None:
    conn = _connect()
    try:
        with conn:
            with conn.cursor() as cur:
                farmer_updates = _fix_farmers(cur)
                payload_updates = _fix_change_request_payloads(cur)
        print(
            "[fix-farmer-enums] Updated "
            f"{farmer_updates} farmer row(s), "
            f"{payload_updates} change-request payload(s)"
        )
    finally:
        conn.close()


if __name__ == "__main__":
    main()
