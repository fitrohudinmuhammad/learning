from odoo import api, fields, models


class InvoiceReportWizard(models.TransientModel):
    _name = 'invoice.report.wizard'

    date_from = fields.Date()
    date_to = fields.Date()
    salesperson_id = fields.Many2one('res.users')

    def do_action(self):
        params = {
            'date_from': self.date_from,
            'date_to': self.date_to,
            'salesperson_id': self.salesperson_id
        }
        return self.env['documents.document']._action_open_invoice_report(params)
