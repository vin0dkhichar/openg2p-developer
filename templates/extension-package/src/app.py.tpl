# ruff: noqa: E402
import asyncio
import logging

from .config import Settings

_config = Settings.get_config()

from openg2p_fastapi_common.app import Initializer as BaseInitializer
from openg2p_registry_core.app import Initializer as CoreInitializer

from .register_domain.factory import G2PRegisterDomainFactory

_logger = logging.getLogger(_config.logging_default_logger_name)


class Initializer(BaseInitializer):
    def initialize(self, **kwargs):
        super().initialize()
        CoreInitializer().initialize()
        G2PRegisterDomainFactory()

    def migrate_database(self, args):
        async def migrate():
            _logger.info("Migrating {{LABEL}} extension database (no domain tables yet)")
            # Add await Model.create_migrate() calls here as you define register models.

        asyncio.run(migrate())
