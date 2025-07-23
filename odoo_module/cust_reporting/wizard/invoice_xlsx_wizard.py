from odoo import api, fields, models


class InvoiceReportXlsxWizard(models.TransientModel):
    _name = 'invoice.report.xlsx.wizard'

    date_from = fields.Date()
    date_to = fields.Date()
    salesperson_id = fields.Many2one('res.users')

    def do_action(self):
        self.ensure_one()
        params = {
            'date_from': self.date_from,
            'date_to': self.date_to,
            'salesperson_id': self.salesperson_id
        }
        return self.env.ref('cust_reporting.action_report_invoice_xlsx').report_action(self)
