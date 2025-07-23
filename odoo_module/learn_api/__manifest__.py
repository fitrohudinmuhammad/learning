{
    'name': 'Learn APIxOdoo',
    'version': '15.0.1.0.0',
    'category': 'Product',
    'description': """
        * Add new function to send task to celery
    """,
    'website': 'https://www.portcities.net',
    'author': 'Portcities Ltd.',
    'depends': ['product', 'web'],
    'data': [
        'views/product_template_views.xml'
    ],
    'assets': {
        'web.assets_qweb': [
            'learn_api/static/src/xml/*.xml',
        ],
        'web.assets_backend': [
            'learn_api/static/src/xml/*.xml',
        ],
    },
    'installable': True,
    'auto_install': False,
    'application': False
}
