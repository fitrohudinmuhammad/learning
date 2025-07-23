import odoorpc


odoo = odoorpc.ODOO('localhost', port='8010', timeout=10000)
odoo.login('test_store', 'admin', '1')

scheduler = odoo.env['ir.cron'].search([('active', '=', False)])
print (scheduler)
# write({
#     'active': True
# })