{
    'name': 'Qweb JS',
    'version': '16.0.0.0.1',
    "sequence": 1,
    'Summary': '',
    'description': '',
    'author': 'Portcities Ltd',
    'website': 'https://www.portcities.net',
    'depends': ['web', 'hr_expense'],
    'data': [
    ],
    'active': True,
    'installable': True,
    'auto_install': False,
    'application': False,
    'license': 'AGPL-3',
    'assets': {
        'web.assets_backend': [
            'qweb_js/static/src/views/*.xml',
            'qweb_js/static/src/views/*.js',
            'qweb_js/static/src/xml/*.xml',
        ],
    },
}
