# import odoorpc


# odoo = odoorpc.ODOO('localhost', port='8066', timeout=10000)
# print (odoo)
# odoo.login('o16ce', 'admin', '1')
# print (odoo.env.user)

# old_prod = odoo.env['product.product'].browse(18)
# print (old_prod)


b = 5
for i in range(0,10):
    for j in range(b,b+5):
        print (i,j)
    b += 5
    