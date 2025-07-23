import odoorpc


odoo = odoorpc.ODOO('34.84.109.17', port='8069', timeout=10000)
odoo.login('uat_store_9644', 'admin', 'maruetsu2021')

currency = odoo.env['res.currency'].search([('name', '=', 'JPY'), ('active', '=', False)])
if currency:
    odoo.env['res.currency'].browse(currency[0]).write({
        'active': True
    })
currency = odoo.env['res.currency'].search([('name', '=', 'JPY')])

conf = odoo.env['res.config.settings'].create({})
result = odoo.env['res.config.settings'].browse(conf).write({
    'currency_id': currency[0],
})
