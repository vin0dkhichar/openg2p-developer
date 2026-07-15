"""Normalize legacy farmer seed / DB enum values to match extension schemas."""

from __future__ import annotations

import os
import re
from copy import deepcopy
from functools import lru_cache
from pathlib import Path
from typing import Any

VALID_SOURCE_OF_INCOME = frozenset(
    {
        "CROP_PRODUCTION",
        "LIVESTOCK_PRODUCTION",
        "GOVERNMENT_NGO_SUPPORT",
        "OTHERS",
    }
)

SOURCE_OF_INCOME_LEGACY = {
    "CROP_FARMING": "CROP_PRODUCTION",
    "LIVESTOCK": "LIVESTOCK_PRODUCTION",
    "BUSINESS_TRADE": "OTHERS",
    "WAGE_LABOR": "OTHERS",
    "REMITTANCES": "OTHERS",
}

SOURCE_OF_INCOME_OTHER_LABELS = {
    "BUSINESS_TRADE": "Business / trade",
    "WAGE_LABOR": "Wage labor",
    "REMITTANCES": "Remittances",
}

LOOKUP_VALUE_FIELDS = frozenset(
    {
        "commodity",
        "season",
        "livestock_type",
        "breed",
        "water_source",
        "means_of_acquisition",
        "soil_fertility",
        "source_of_income",
    }
)

_LOOKUP_ROW_RE = re.compile(
    r"\('([^']+)','([^']+)','([^']+)','[^']*',[^,]*,\d+\)"
)


def _default_lookup_sql_path() -> Path | None:
    workspace = os.environ.get("OPENG2P_WORKSPACE")
    if not workspace:
        return None
    path = (
        Path(workspace).resolve()
        / "farmer-registry"
        / "farmer-extension"
        / "src/openg2p_registry_farmer_extension/meta_data/lookup-data/g2p_attribute_values.sql"
    )
    return path if path.is_file() else None


def parse_lookup_value_id_map(path: Path) -> dict[str, str]:
    """Map g2p_attribute_values.value_id -> value_code from seed SQL."""
    text = path.read_text(encoding="utf-8")
    return {
        value_id: value_code
        for value_id, _attribute_id, value_code in _LOOKUP_ROW_RE.findall(text)
    }


@lru_cache(maxsize=1)
def lookup_value_id_map() -> dict[str, str]:
    path = _default_lookup_sql_path()
    if path is not None:
        return parse_lookup_value_id_map(path)
    # Fallback when OPENG2P_WORKSPACE is unset (matches g2p_attribute_values.sql).
    return {
        "SOI_CROP_PRODUCTION": "CROP_PRODUCTION",
        "SOI_LIVESTOCK_PRODUCTION": "LIVESTOCK_PRODUCTION",
        "SOI_GOVERNMENT_NGO_SUPPORT": "GOVERNMENT_NGO_SUPPORT",
        "SOI_OTHERS": "OTHERS",
        "CROP_WHEAT": "WHEAT",
        "CROP_TEFF": "TEFF",
        "CROP_MAIZE": "MAIZE",
        "CROP_SESAME": "SESAME",
        "CROP_MALT_BARLEY": "MALT_BARLEY",
        "CROP_TOMATO": "TOMATO",
        "CROP_ONION": "ONION",
        "CROP_AVOCADO": "AVOCADO",
        "CROP_BANANA": "BANANA",
        "CROP_MANGO": "MANGO",
        "CROP_SOYBEAN": "SOYBEAN",
        "CROP_OTHER": "OTHER",
        "SEASON_SUMMER": "SUMMER",
        "SEASON_MONSOON": "MONSOON",
        "SEASON_WINTER": "WINTER",
        "LSTK_CATTLE": "CATTLE",
        "LSTK_CAMEL": "CAMEL",
        "LSTK_SHEEP": "SHEEP",
        "LSTK_GOAT": "GOAT",
        "LSTK_CHICKEN": "CHICKEN",
        "LSTK_DONKEY": "DONKEY",
        "LSTK_HORSE": "HORSE",
        "LSTK_MULE": "MULE",
        "WS_RAINFED": "RAINFED",
        "WS_IRRIGATION_GROUND": "IRRIGATION_GROUND_WATER",
        "WS_IRRIGATION_SURFACE": "IRRIGATION_SURFACE_WATER",
        "WS_WELL_GROUND": "WELL_GROUND_WATER",
        "WS_WATER_HARVESTING": "WATER_HARVESTING",
        "WS_SURFACE_WATER": "SURFACE_WATER",
        "MOA_INHERITANCE": "INHERITANCE",
        "MOA_DONATION_GIFT": "DONATION_GIFT",
        "MOA_EXPROPRIATION": "EXPROPRIATION",
        "MOA_RENTING_LEASING": "RENTING_LEASING",
        "MOA_REALLOCATION": "REALLOCATION",
        "MOA_DIVORCE_SETTLEMENT": "DIVORCE_SETTLEMENT",
        "SF_HIGH": "HIGH",
        "SF_MEDIUM": "MEDIUM",
        "SF_LOW": "LOW",
        "BREED_IMPROVED": "IMPROVED",
        "BREED_LOCAL": "LOCAL",
        "BREED_HYBRID": "HYBRID",
    }


def normalize_lookup_value(value: Any) -> Any:
    if not isinstance(value, str):
        return value
    return lookup_value_id_map().get(value, value)


def normalize_lookup_fields(record: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(record)
    for field in LOOKUP_VALUE_FIELDS:
        if field not in normalized:
            continue
        value = normalized.get(field)
        if value is None or value == "":
            continue
        normalized[field] = normalize_lookup_value(value)
    return normalized


def normalize_source_of_income_fields(record: dict[str, Any]) -> dict[str, Any]:
    """Return a copy of *record* with source_of_income aligned to SourceOfIncomeEnum."""
    if "source_of_income" not in record:
        return record

    normalized = normalize_lookup_fields(record)
    value = normalized.get("source_of_income")
    if value is None or value == "":
        normalized["source_of_income"] = None
        return normalized

    if value in SOURCE_OF_INCOME_LEGACY:
        legacy = value
        mapped = SOURCE_OF_INCOME_LEGACY[legacy]
        normalized["source_of_income"] = mapped
        if mapped == "OTHERS" and not normalized.get("source_of_income_other"):
            normalized["source_of_income_other"] = SOURCE_OF_INCOME_OTHER_LABELS.get(
                legacy, legacy.replace("_", " ").title()
            )
        return normalized

    if value not in VALID_SOURCE_OF_INCOME:
        normalized["source_of_income"] = "OTHERS"
        if not normalized.get("source_of_income_other"):
            normalized["source_of_income_other"] = str(value).replace("_", " ").title()

    return normalized


def normalize_record(record: dict[str, Any]) -> dict[str, Any]:
    return normalize_source_of_income_fields(normalize_lookup_fields(record))


def normalize_farmer_extra(record: dict[str, Any]) -> dict[str, Any]:
    return normalize_record(record)


def normalize_json_tree(value: Any) -> Any:
    """Recursively normalize enum / lookup fields inside nested JSON payloads."""
    if isinstance(value, list):
        return [normalize_json_tree(item) for item in value]
    if isinstance(value, dict):
        updated = {key: normalize_json_tree(item) for key, item in value.items()}
        return normalize_record(updated)
    return value


def normalize_json_tree_if_changed(value: Any) -> tuple[Any, bool]:
    normalized = normalize_json_tree(deepcopy(value))
    return normalized, normalized != value
