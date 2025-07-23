import csv
import random
from datetime import datetime
import logging
import os

import requests
import boto3
from botocore.exceptions import ClientError
import celery
from celery.utils.log import get_task_logger
import psycopg2

from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

import config


import raven
from raven.contrib.celery import register_signal, register_logger_signal

logger = get_task_logger(__name__)
class Celery(celery.Celery):

    def on_configure(self):
        client = raven.Client(config.SENTRY_DSN)

        register_logger_signal(client)

        register_signal(client)

app = Celery('workers', broker=config.BROKER_URL)

@app.task
def check_stock_update_sandbox(branch, args={}):
    logger.info("starting sandbox task")
    args.update({
        "disable_bucket": True,
        "disable_notify": True,
        "sandbox": True,
    })
    res = check_stock_update(branch, args)
    logger.info("finish sandbox task")
    return res

@app.task
def check_stock_update(branch, args={}):
    logger.info("starting task")
    params = get_params(branch, args)
    data = pull_stock_data(params)
    data_length = len(data)
    params.update({"data_length": data_length})
    data_exist = data_length > 0
    logger.info("pulled data exist : %s" % data_exist)
    if data_exist:
        create_stock_csv(params, data)
        # clean memmory
        data = False
        disable_bucket = params.get('disable_bucket')
        if not disable_bucket:
            sent = send_stock_csv(params)
            disable_notify = params.get('disable_notify')
            if sent and not disable_notify:
                notify_stock_csv(params)
    return params

def get_params(branch, args):
    production = args.get("production", False)
    if production:
        logger.info("config production")
    else:
        logger.info("config dev")

    branch_codes = config.BRANCH_CODES
    branch_code = branch_codes.get(branch, False)
    if not branch_code:
        logger.error("branch code not found")
        raise Exception("branch code not found")

    # sql config
    branch_dbs = config.BRANCH_DBS
    branch_db = branch_dbs.get(branch, {})

    file_name = "inventory_%s.csv" % (datetime.now().strftime("%Y%m%d%H%M%S"))
    local_path = "%s/DEV_%s_%s" % (config.FILE_PATH, branch_code, file_name)
    aws_path = "%s/%s/%s" % (config.AWS_PREFIX, branch_code, file_name)

    if production:
        local_path = "%s/PROD_%s_%s" % (config.FILE_PATH, branch_code, file_name)
        aws_path = "%s/%s/%s" % (config.PROD_AWS_PREFIX, branch_code, file_name)
    
    res = {
        "production": production,
        "branch": branch,
        "branch_code": branch_code,
        "branch_db": branch_db,
        "file_name": file_name,
        "local_path": local_path,
        "aws_path": aws_path,
        "store_code": args.get("store_code", []),
        "initial_stock": args.get("initial_stock", False),
        "disable_bucket": args.get("disable_bucket", False),
        "disable_notify": args.get("disable_notify", False),
        "sandbox": args.get("sandbox", False),
        "data_length": 0,
        "notify_url": config.NOTIFY_URL,
        "aws_access_key": config.AWS_ACCESS_KEY,
        "aws_secret_key": config.AWS_SECRET_KEY,
        "aws_region": config.AWS_REGION,
        "aws_bucket": config.AWS_BUCKET,
        "aws_prefix": config.AWS_PREFIX,
    }

    if production:
        res.update({
            "notify_url": config.PROD_NOTIFY_URL,
            "aws_access_key": config.PROD_AWS_ACCESS_KEY,
            "aws_secret_key": config.PROD_AWS_SECRET_KEY,
            "aws_region": config.PROD_AWS_REGION,
            "aws_bucket": config.PROD_AWS_BUCKET,
            "aws_prefix": config.PROD_AWS_PREFIX,
        })
    
    logger.info("success generating params")
    return res

def pull_stock_data(params):
    db = params.get("branch_db")
    conn = psycopg2.connect(
        user=db.get("user"), 
        password=db.get("password"),
        host=db.get("host"),
        port=db.get("port"),
        database=db.get("database")
    )
    logger.info("success connect db")
    cr = conn.cursor()
    store_code = params.get('store_code')
    branch_code = str(params.get('branch_code'))
    initial_stock = params.get('initial_stock')
    if initial_stock:
        stmt = ""
        first_code = True
        for code in store_code:
            if not first_code:
                stmt += "UNION"
            else:
                first_code = False
            stmt += """
            (WITH filtered AS (
            SELECT product_code,qty
            FROM stock_quant_by_store
            WHERE store_code = '%s'
            )
            SELECT %s, '%s',m.product_jan_1,
            case when s.qty IS NULL then 0::integer when s.qty < 0 then 0::integer else FLOOR(s.qty)::integer end 
            FROM master_data_product m
            LEFT JOIN filtered s ON s.product_code = m.product_code 
            WHERE TRIM(m.product_jan_1) != '' AND m.product_jan_1 IS NOT NULL)
            """ % (code, branch_code, code)
        cr.execute(stmt)
    else:
        if len(store_code) > 0:
            cr.execute("""
            with updated as (
            update stock_quant_by_store set qty_updated = 'f'
            where qty_updated = 't' AND store_code in %s
            returning store_code, product_code, case when qty < 0 then 0::integer else FLOOR(qty)::integer end as qty
            )
            select """ + branch_code + """, u.store_code,m.product_jan_1,u.qty
            from updated u left join master_data_product m 
            on u.product_code = m.product_code 
            where TRIM(m.product_jan_1) != '' AND m.product_jan_1 IS NOT NULL
            """, [tuple(store_code)])
        else:
            cr.execute("""
            with updated as (
            update stock_quant_by_store set qty_updated = 'f'
            where qty_updated = 't'
            returning store_code, product_code, case when qty < 0 then 0::integer else FLOOR(qty)::integer end as qty
            )
            select """ + branch_code + """, u.store_code,m.product_jan_1,u.qty
            from updated u left join master_data_product m 
            on u.product_code = m.product_code 
            where TRIM(m.product_jan_1) != '' AND m.product_jan_1 IS NOT NULL
            """)
    data = cr.fetchall()
    conn.commit()
    cr.close()
    conn.close()
    return data

def create_stock_csv(params, data):
    with open(params.get('local_path'), 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerows(data)
    logger.info("write local file success")
    return True

def send_stock_csv(params):
    client = boto3.client('s3', 
    aws_access_key_id=params.get('aws_access_key'), 
    aws_secret_access_key=params.get('aws_secret_key'), 
    region_name=params.get('aws_region'))
    # if upload process failed it return error, so we just need to catch
    try:
        client.upload_file(params.get('local_path'), params.get('aws_bucket'), params.get('aws_path'))
        os.remove(params.get('local_path'))
        logger.info("aws upload %s success" % params.get('aws_path'))
    except ClientError as e:
        raise Exception("aws upload error %s" % e)
        logger.error("aws upload error %s" % e)
        return False
    return True

def notify_stock_csv(params):
    data = {
        "data_type": 1,
        "file_name": params.get('aws_path'),
    }
    logger.info("notify payload %s" % data)
    # https://urllib3.readthedocs.io/en/latest/reference/urllib3.util.html
    adapter = HTTPAdapter(max_retries=Retry(
        total=config.NOTIFY_TOTAL,
        backoff_factor=config.NOTIFY_BACKOFF_FACTOR,
        status_forcelist=tuple( x for x in requests.status_codes._codes if not (x >= 200 and x < 300)),
        method_whitelist=["GET", "POST"]
    ))
    http = requests.Session()
    http.mount("https://", adapter)
    http.mount("http://", adapter)

    res = http.post(params.get('notify_url'), json=data)
    res.raise_for_status()
    logger.info("notify status code %s" % res.status_code)
    return True
