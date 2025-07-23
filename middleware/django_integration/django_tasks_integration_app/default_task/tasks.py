from __future__ import absolute_import, unicode_literals

import sys, os, time
import asyncio
from pathlib import Path

DJANGO_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, os.path.abspath(DJANGO_DIR))

# FTP_DIR = Path(str(Path(__file__).resolve().parent.parent.parent.parent) + '/ftp_integration')
# sys.path.insert(0, os.path.abspath(FTP_DIR))

from celery import shared_task, chord, group, chain
from celery.utils.log import get_task_logger
from celery_dyrygent.workflows import Workflow

logger = get_task_logger(__name__)
asyncio.get_event_loop().close()
asyncio.get_event_loop().is_closed()


@shared_task()
def run_main_flow(self):
    logger.info('Task Main Flow is Run')