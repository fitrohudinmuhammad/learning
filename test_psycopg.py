import psycopg2, logging, psycopg2.extensions
from psycopg2.extras import LoggingConnection

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger('notice')

conn = psycopg2.connect(connection_factory=LoggingConnection,
            user='postgres',
            password='postgres',
            database='usmh_dev',
            host='localhost',
            port='5432')
conn.initialize(logger)
cr = conn.cursor()

cr.execute("""SELECT check_query()""")

conn.commit()
conn.close()