{
    'name': 'PCI API Framework',
    'version': '16.0.1.0.0',
    'author': 'Port Cities',
    'website': 'https://www.portcities.net',
    "sequence": 1,
    'category': 'Technical',
    'summary': "API integration",
    'license': 'LGPL-3',
    'description': """
    """,
    'depends': [
        'base',
        'mail',
    ],
    "external_dependencies": {
        "python": [
            "schema",
            "pypeg2",
        ],
    },
    'data': [
        'security/security.xml',
        'security/ir.model.access.csv',
        'data/pci_api_data.xml',
        'views/pci_api_handler_views.xml',
        'views/pci_api_logs_views.xml',
        'views/api_handler_menuitem.xml',
    ],
    'qweb': [
    ],
    'installable': True,
    'application': False,
    'auto_install': False,
}
