import psycopg2, html
from bs4 import BeautifulSoup

conn = psycopg2.connect(
            user='postgres',
            password='postgres',
            database='ntranslate15',
            host='localhost',
            port='5432')
cr = conn.cursor()

cr.execute("""
    SELECT irv.arch_db
    FROM ir_ui_view irv
    JOIN website_page wp on irv.id = wp.view_id
    WHERE wp.id = %s
""" % (9))
result = cr.fetchall()
for res in result:
    soup = BeautifulSoup(res[0], 'html.parser')
    paragraphs = [element.replace('\n','').replace('  ','') for element in soup.find_all(string=True) if element.strip() != '']
    for para in paragraphs:
        if para[:11] == 'Founder and':
            query = """SELECT id, src FROM ir_translation WHERE src ilike '%s' AND state = 'to_translate' AND lang != 'en_US' LIMIT 1""" % (para.replace("'","''"))
            cr.execute(query)
            data = cr.fetchall()
            print (para, data)

            # waktu di search by query src bentuk text
            # Founder and chief visionary, Tony is the driving force behind the company. He loves
                                # to keep his hands full by participating in the development of the software,
                                # marketing, and customer experience strategies.
            # semisal di translate haruse bisa cuman hasil dari paragraphs tidak ada enter atau 
            # Founder and chief visionary, Tony is the driving force behind the company. He lovesto keep his hands full by participating in the development of the software,marketing, and customer experience strategies.
            # jadi waktu update dengan pencarian src = Founder and chief visionary, Tony is the driving force behind the company. He lovesto keep his hands full by participating in the development of the software,marketing, and customer experience strategies.
            # tidak bakal ketemu datanya

            if data == None:
                cr.execute("""
                    SELECT id, src FROM ir_translation WHERE src ilike '%s%s' AND state = 'to_translate' AND lang != 'en_US' LIMIT 1
                """ % (para.replace("'","''"), '%'))
                other_data = cr.fetchall()
                if other_data:
                    print ('other --> ', other_data)

conn.commit()
conn.close()