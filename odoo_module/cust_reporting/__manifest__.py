{
    "name": "Cust Reporting",
    "author": "Port Cities",
    "version": "17.0.0.0.1",
    "summary": "Contain all custom report spreadsheet",
    "website": "portcities.net",
    "category": "Documents",
    "depends": [
        "base",
        "sale",
        "purchase",
        "documents",
        "account",
        "report_xlsx",
    ],
    "data": [
        "security/ir.model.access.csv",

        "views/account_move_view.xml",

        "wizard/invoice_wizard_view.xml",
        "wizard/invoice_xlsx_wizard_view.xml",
        "wizard/invoice_wizard_menu.xml",

        "reports/invoices_report_template.xml",
        "reports/invoices_report_views.xml",
    ],
    "license": "LGPL-3",
    "installable": True,
    "application": True,
}
