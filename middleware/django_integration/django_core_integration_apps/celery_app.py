from __future__ import absolute_import, unicode_literals

import os
from celery import Celery
from celery_dyrygent.tasks import register_workflow_processor
from pathlib import Path


app = Celery('celery_app')

workflow_processor = register_workflow_processor(app)

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'django_core_integration_apps.settings')
app.config_from_object('django.conf:settings', namespace='CELERY')

tasks = []
for root, dirs, files in os.walk(os.path.abspath(Path(__file__).resolve().parent.parent) + '/django_tasks_integration_app', topdown=False):
    for name in dirs:
        if 'task' in name:
            tasks.append('django_tasks_integration_app.' + name)
print ('wkwkwkwk')
print (tasks)
app.autodiscover_tasks(tasks, force=True)