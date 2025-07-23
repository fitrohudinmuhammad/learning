import xmlrpc.client
import csv

# file = open('testing_active_store.csv')
# csvreader = csv.reader(file)
list_update = []
# for row in csvreader:
#     # print (row)
#     if not str(row[5]):
    #         continue
    # vals = {
    #     'port': int(row[0]),
    #     'db': str(row[1]),
    #     'url': str(row[6]),
    #     'store_name': str(row[7]),
    #     'store_kanji': str(row[8]),
    #     'user': 'admin',
    #     'password': 'maruetsu2021'
    # }
    # list_update.append(vals)

vals = {
    'port': '8069',
    'db': 'uat_store_9156',
    'url': '34.84.109.17',
    'store_name': 'M Kawasaki Miyamae',
    'store_kanji': 'M Kawasaki Miyamae',
    'user': 'admin',
    'password': 'maruetsu2021'
}
list_update.append(vals)
# print (list_update)
i = 1
for lu in list_update:
    url = lu['url']
    dbname = lu['db']
    username = lu['user']
    pwd = lu['password']
    store_name = lu['store_name']
    store_kanji = lu['store_kanji']
    port = lu['port']

    common = xmlrpc.client.ServerProxy('{}/xmlrpc/2/common'.format(url))
    uid = common.authenticate(dbname, username, pwd, {})
    models = xmlrpc.client.ServerProxy('{}/xmlrpc/2/object'.format(url))

    def search_read_data(table, domain, fields):
        # get needed fields
        values = models.execute_kw(dbname, uid, pwd, table, 'search_read', domain, fields)
        return values

    def search_data(table, domain, fields):
        # get needed fields
        values = models.execute_kw(dbname, uid, pwd, table, 'search', domain, fields)
        return values

    def create_data(table, data):
        models.execute_kw(dbname, uid, pwd, table, 'create', data)

    def update_data(table, data):
        models.execute_kw(dbname, uid, pwd, table, 'write', data)

    def delete_data(table, id):
        models.execute_kw(dbname, uid, pwd, table, 'unlink', id)

    print ('-------------------------- '+str(i)+' '+ dbname +' -------------------------')
    i+=1
