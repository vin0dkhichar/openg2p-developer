"""Normalize legacy farmer seed / DB enum values to match extension schemas."""

from __future__ import annotations

from copy import deepcopy
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


def normalize_source_of_income_fields(record: dict[str, Any]) -> dict[str, Any]:
    """Return a copy of *record* with source_of_income aligned to SourceOfIncomeEnum."""
    if "source_of_income" not in record:
        return record

    normalized = dict(record)
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


def normalize_farmer_extra(record: dict[str, Any]) -> dict[str, Any]:
    return normalize_source_of_income_fields(record)


def normalize_json_tree(value: Any) -> Any:
    """Recursively normalize enum fields inside nested JSON payloads."""
    if isinstance(value, list):
        return [normalize_json_tree(item) for item in value]
    if isinstance(value, dict):
        updated = {key: normalize_json_tree(item) for key, item in value.items()}
        if "source_of_income" in updated:
            return normalize_source_of_income_fields(updated)
        return updated
    return value


def normalize_json_tree_if_changed(value: Any) -> tuple[Any, bool]:
    normalized = normalize_json_tree(deepcopy(value))
    return normalized, normalized != value
