import sys, pathlib, os, psycopg2
import sentry_sdk

BASE_DIR = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, os.path.abspath(BASE_DIR))

from ftp_integration import setting

sentry_sdk.init({
    "dsn": 'https://4524dbb9f2684220bc75d10ecd55695e@o1043837.ingest.sentry.io/6013594' #Sentri-UAT
    # "dsn": 'https://80414a9e455043319ba8ddc4a7b55f93@o1071874.ingest.sentry.io/6069704' #Sentri-Live
})


def connection_db():
    config = setting.config()
    conn = psycopg2.connect(
            user=config['MIDDLEWARE_DB']['username'], 
            password=config['MIDDLEWARE_DB']['passwd'],
            database=config['MIDDLEWARE_DB']['database'],
            host=config['MIDDLEWARE_DB']['url'], 
            port=config['MIDDLEWARE_DB']['port'])
    return conn

# Query untuk check / compare on hand
def quant_data_validation():
    conn = connection_db()
    curs = conn.cursor()
    quant_validation_sql = "SELECT stock_quant_validation();"
    curs.execute(quant_validation_sql)
    result_sql = """SELECT store_code FROM stock_quant_validation WHERE diff = false GROUP BY store_code"""
    curs.execute(result_sql)
    result = curs.fetchall()
    print(result)
    if result:
        curs.close()
        conn.close()
        raise Exception("Stock Quant Validation Error")
    curs.close()
    conn.close()

quant_data_validation()