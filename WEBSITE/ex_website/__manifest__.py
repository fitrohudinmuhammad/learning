{
    'name': 'Ex Website',
    'version': '16.0.0.0.1',
    "sequence": 1,
    'Summary': '',
    'description': """
        Try create a new pages website
    """,
    'author': 'Portcities Ltd',
    'website': 'https://www.portcities.net',
    'depends': ['website'],
    'data': [
        # 'security/ir.model.access.csv',
        'views/component_website.xml',
        'views/new_pages.xml',
        'views/child_page.xml',
        'views/menu_bar_template.xml',
    ],
    'active': True,
    'installable': True,
    'auto_install': False,
    'application': False,
    'license': 'AGPL-3',
    'assets': {
        'web.assets_frontend': [
            'ex_website/static/src/scss/style.scss',
        ]
    }
}
