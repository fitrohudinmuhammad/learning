import odoorpc


odoo = odoorpc.ODOO('localhost', port='8010', timeout=10000)
odoo.login('js_connector_odoo_db', 'admin', '1')

currency = odoo.env['stock.picking.type'].create({
    'name': 'Unpack Transaction',
    'sequence_code': 'UNPACK',
    'code': 'internal',
    'default_location_src_id': 13,
    'default_location_dest_id': odoo.env['stock.location'].search([('name', '=', 'Stock'), ('company_id', '=', odoo.env.user.company_id.id)])[0],
    'warehouse_id': odoo.env['stock.warehouse'].search([('code', '=', 'WH')])[0],
})