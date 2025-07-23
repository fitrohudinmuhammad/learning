import odoorpc, csv

# odoo = odoorpc.ODOO('34.84.109.17', port='8069', timeout=10000)
# odoo.login('uat_store_9156', 'admin', 'maruetsu2021')

# unpack_type_id = odoo.env['stock.picking.type'].search([('name', '=', 'Unpack')])
# if unpack_type_id:
#     unpack_type = odoo.env['stock.picking.type'].browse(unpack_type_id[0])
#     print (unpack_type.default_location_dest_id, unpack_type.default_location_src_id)

file = open('testing_active_store.csv')
csvreader = csv.reader(file)
list_update = []
for row in csvreader:
    vals = {
        'port': int(row[0]),
        'db': str(row[1]),
        'url': str(row[2]),
        'user': str(row[3]),
        'password': str(row[4])
    }
    list_update.append(vals)

print (list_update)
for list in list_update:
    print (list['db'])
    odoo_ls = odoorpc.ODOO(list['url'], port=list['port'], timeout=10000)
    odoo_ls.login(list['db'], list['user'], list['password'])

    if not odoo_ls.env['stock.picking.type'].search([('name', '=', 'Unpack')]):
        seq_id = odoo_ls.env['ir.sequence'].create({
            'name': 'My Company Sequence WH-Unpack',
            'implementation': 'standard',
            'code': '',
            'prefix': 'WH/WH-Unpack/',
            'padding': 5
        })

        unpack_new = odoo_ls.env['stock.picking.type'].create({
            'name': 'Unpack',
            'sequence_id': seq_id,
            'code': 'internal',
            'warehouse_id': 1,
            'sequence_code': 'WH-Unpack',
            'default_location_src_id': 13,
            'default_location_dest_id': 8
        })
        odoo_ls.env['stock.warehouse'].browse(1).write({
            'maruetsu_unpack_picking_type_id': unpack_new
        })
    print ('DONE')
    