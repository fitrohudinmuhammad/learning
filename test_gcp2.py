from pprint import pprint
from googleapiclient import discovery
from oauth2client.client import GoogleCredentials
import os

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = '/opt/gcloud/digital-elysium-304405-2473a9a4481d-bigquery.json'

credentials = GoogleCredentials.get_application_default()

service = discovery.build('sqladmin', 'v1', credentials=credentials)

# # Project ID of the project that contains the instance.
project = 'digital-elysium-304405'  # TODO: Update placeholder value.

print(credentials, service)

# # Cloud SQL instance ID. This does not include the project ID.
instance = 'udmh-stresstest'  # TODO: Update placeholder value.

instances_import_request_body = {
    "importContext":
    {
        "fileType": "CSV",
        "uri": "gs://{}/{}".format('usmh_staging','bg_odoo_vinx_teraoka_stream.csv'),
        "database": "uat_store_0234",
        "csvImportOptions":
        {
            "table": "vinx_bigquery_transactions",
        }
    }
}

print (instances_import_request_body)

request = service.instances().import_(project=project, instance=instance, body=instances_import_request_body)
response = request.execute()

# TODO: Change code below to process the `response` dict:
pprint(response)