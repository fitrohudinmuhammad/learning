{
    'name': 'Indivara Report Faktur',
    'version': '16.0.1.1.8',
    'summary': 'Module for Reporting Faktur',
    'category': 'Accounting',
    'author': 'Indivara Group',
    'maintainer': 'Indivara Group',
    'website': 'https://www.indivaragroup.com/',
    'description': """
        * 2025-02-03
            - Add new wizard to generate report faktur
        *. 2025-06-14
            - Update column on Faktur Excel (Period Dok Pendukung)
    """,
    'contributors': [
        'Fitrohudin <muhammad.fithrohudin@indivaragroup.com>',
    ],
    'depends': [
        'account',
        'report_xlsx',
    ],
    'data': [
        'views/account_move_views.xml',
        'report/report_view.xml',
    ],
    'installable': True,
    'auto_install': False,
    'application': True,
}
