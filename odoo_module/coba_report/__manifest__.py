{
    'name': 'Nyoba Report',
    'version': '16.0.0.0.1',
    "sequence": 1,
    'Summary': '',
    'description': """
        New menu apps with name
    """,
    'author': 'Portcities Ltd',
    'website': 'https://www.portcities.net',
    'depends': ['base'],
    'data': [
        'security/ir.model.access.csv',
        'views/table_source_views.xml',
        'views/table_a_views.xml',
        'views/table_b_views.xml',
        # 'views/table_report_views.xml',
    ],
    'active': True,
    'installable': True,
    'auto_install': False,
    'application': False,
    'license': 'AGPL-3',
}
