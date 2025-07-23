import os
from google.cloud import bigquery

os.environ["GOOGLE_APPLICATION_CREDENTIALS"]= '/opt/gcloud/digital-elysium-304405-2473a9a4481d-bigquery.json'


client = bigquery.Client()
# bucket_name = 'usmh_staging'
# project = 'digital-elysium-304405'
# dataset_id = 'kasumi_stream_data'
# table_id = 'bq_odoo_vinx_teraoka_stream'

# destination_uri = "gs://{}/{}".format(bucket_name, 'bg_odoo_vinx_teraoka_stream.csv')
# dataset_ref = bigquery.DatasetReference(project, dataset_id)
# table_ref = dataset_ref.table(table_id)
# job_config = bigquery.job.ExtractJobConfig(print_header=False)

# extract_job = client.extract_table(
#     table_ref,
#     destination_uri,
#     location="asia-northeast1",
#     job_config=job_config,
# )
# print (extract_job)
# extract_job.result()  # Waits for job to complete.

# print(
#     "Exported {}:{}.{} to {}".format(project, dataset_id, table_id, destination_uri)
# )
