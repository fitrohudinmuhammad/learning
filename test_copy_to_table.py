import psycopg2
from pathlib import Path

conn = psycopg2.connect(
        host="localhost",
        database="usmh_dev",
        user="postgres",
        password="postgres")
curs = conn.cursor()
