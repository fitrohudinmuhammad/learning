import sqlite3

conn = sqlite3.connect('db.sqlite3')
print (conn)
curs = conn.cursor()
# curs.execute("""SELECT name FROM sqlite_schema
#                 WHERE type='table'
#                 ORDER BY name"""
#             )
curs.execute("SELECT * from django_admin_log")
record = curs.fetchall()
print(record)
conn.close()