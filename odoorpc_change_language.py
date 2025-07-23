import odoorpc


odoo = odoorpc.ODOO('localhost', port='8030', timeout=10000)
odoo.login('k_dev', 'admin', '1')

langs_ids = [
    ['Inventory Adjustment Log','在庫調整ログ'],
    ['Store Name','店舗名'],
    ['Product Category','商品カテゴリ'],
    ['Product Name','商品名'],
    ['Standard Code','標準コード'],
    ['Before','調整前'],
    ['After','調整後'],
    ['Difference','差異'],
    ['Date','日付'],
    ['User','ユーザー'],
    ['Stock Conversion','在庫換算'],
    ['Product','商品コード'],
    ['Inventory Product Conversion','商品在庫換算'],
    ['Stock Conversion Quantity','在庫換算数量'],
    ['Stock Unpack Transaction','在庫換算取引'],
    ['Stock Conversion','在庫換算'],
    ['Current On Hand Qty','手持在庫'],
    ['Processed','処理済み'],
    ['Outdated Theoretical Quantities','従来理論数量'],
    ['Difference different than zero','ゼロと異なる差'],
    ['Room Temperature','保存時温度帯区分'],
    ['Room Temperature UOM','保存時温度帯区分単位']
]
for llan in langs_ids:
    langs = odoo.env['ir.translation'].search([('src','=',llan[0]), ('lang', '=', 'ja_JP') ])
    if langs:
        for ln in langs:
            lan = odoo.env['ir.translation'].browse(ln).write({
                'value': llan[1]
            })