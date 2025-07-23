from __future__ import absolute_import, unicode_literals

# This will make sure the app is always imported when
# Django starts so that shared_task will use this app.
import os


os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'django_core_integration_apps.settings')

from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()

from .celery_app import app as celery_app

__all__ = ('celery_app')