"""PBMS Celery worker entrypoint for native dev (openg2p-developer only).

Core PBMS uses KeymanagerCryptoHelper for Bridge API calls. Local dev has no
Keymanager, so we register bg-task Settings from the generated env file first,
then alias KeymanagerCryptoHelper -> build_crypto_helper (local .p12 signing when
CRYPTO_BACKEND=local). No changes to the PBMS product repo are required.
"""

from openg2p_bg_task_celery_workers.config import Settings

Settings.get_config()

import openg2p_fastapi_common.utils.crypto as _crypto
from openg2p_fastapi_common.utils.crypto import build_crypto_helper

_crypto.KeymanagerCryptoHelper = build_crypto_helper  # type: ignore[misc,assignment]

from openg2p_bg_task_celery_workers.main import celery_app  # noqa: E402

__all__ = ["celery_app"]
