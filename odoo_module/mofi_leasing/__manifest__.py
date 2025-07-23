{
    'name': 'Moladin Leasing',
    'version': '16.0.1.1.8',
    'summary': 'Module for Leasing app',
    'category': 'Other',
    'author': 'Port Cities Ltd',
    'maintainer': 'Port Cities Ltd',
    'website': 'https://www.portcities.net/',
    'license': 'LGPL-3',
    'description': """
        Module for Leasing
        - 1.1.5 : 06032024
        -> Add new group Calculate Amortization to make sure only the user from that group able to calculate amortization line number
        -> Add new scheduled action to run the function for generate journal entries based on the amortization line
        -> Remove some unnecessary stuff
        - 1.1.6 : 07032024
        -> Update functon on termination to put number of amount based on different total amount and total amortization amount
        -> code fixing
        - 1.1.7 : 08032024
        --> Bug fix on terminate the contract create double account in the journal entries
        - 1.1.8 : 12032024
        --> Bug fix on terminate amortization line
    """,
    'contributors': [
        'Wisnu Sadewo <wisnu@portcities.net>',
        'Fitrohudin <fitrohudin@portcities.net>',
    ],
    'depends': [
        'base','mail',
        'account',
        'account_accountant',
        'l10n_id_efaktur',
        'sale'
    ],
    'data': [
        'security/res_groups.xml',
        'security/ir.model.access.csv',

        'data/ir_cron.xml',
        'data/ir_actions_server.xml',

        'wizard/loan_entries_views.xml',
        'wizard/payment_entries_views.xml',
        'wizard/interest_entries_views.xml',
        'wizard/reverse_entries_views.xml',
        'wizard/reverse_amortization_views.xml',
        'wizard/contract_termination_views.xml',
        'wizard/confirm_lock_date_contract_views.xml',
        'wizard/confirm_lock_date_amortization_views.xml',

        'views/mofi_bank_account_views.xml',
        'views/mofi_contract_views.xml',
        'views/mofi_amortization_views.xml',
        'views/mofi_fee_type_views.xml',
        'views/mofi_suborder_type_views.xml',
        'views/mofi_order_type_views.xml',
        'views/mofi_branch_views.xml',
        'views/mofi_loan_purpose_views.xml',
        'views/mofi_channel_views.xml',
        'views/mofi_funding_type_views.xml',
        'views/mofi_payment_channel_views.xml',
        'views/mofi_leasing_account_views.xml',
        'views/leasing_menu.xml',
        'views/account_move_views.xml',
        'views/res_partner_views.xml',
        'views/account_journal_views.xml',

    ],
    'installable': True,
    'auto_install': False,
    'application': True,
}
