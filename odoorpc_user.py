import odoorpc


odoo = odoorpc.ODOO('localhost', port='8010', timeout=10000)
odoo.login('o15_learn', 'admin', '1')

# users = odoo.env['res.users'].create({
#     'name': 'user_test',
#     'login': 'admins',
#     'password': '1',
#     'company_id': 1,
#     'partner_id': ''
# })

langs = odoo.env['res.lang'].search([('active', '=', True)])
for lang in langs:
    if odoo.env['res.lang'].browse(lang).code == 'sq_AL':
        users = odoo.env['res.users'].search([('name', '=', 'user_test')])
        if users:
            odoo.env['res.users'].browse(users[0]).write({'lang': 'sq_AL'})
    else:
        lg = odoo.env['res.lang'].search([('code', '=', 'sq_AL'), ('active', '=', False)])
        
        new_lang = odoo.env['base.language.install'].create({'lang': 'sq_AL', 'overwrite': True})
        odoo.env['base.language.install'].browse(new_lang).lang_install()

        users = odoo.env['res.users'].search([('name', '=', 'user_test')])
        if users:
            odoo.env['res.users'].browse(users[0]).write({'lang': 'sq_AL'})
        