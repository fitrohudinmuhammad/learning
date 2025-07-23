from odoo import models, fields, api, _


class AccountMove(models.Model):
    _inherit = 'account.move'


    amortization_count = fields.Integer(string='Entries', compute='_compute_journal_entries_count')
    contract_ref = fields.Many2one('leasing.contract', string="Contract", copy=False)
    amortization_ref = fields.Many2one('mofi.leasing.amortization', string="Amortization", copy=False)
    # account_bank_no = fields.Many2one('mofi.bank.account', string="Bank Account", copy=False)

    def _compute_journal_entries_count(self):
        self.amortization_count = 0
        amortization_count = self.env['mofi.leasing.amortization'].search([('name', '=', self.ref)])
        if amortization_count:
            self.amortization_count = len(amortization_count) or 0

    def action_amortization(self):
        return {
            'name': _('Amortization'),
            'view_mode': 'tree,form',
            'res_model': 'mofi.leasing.amortization',
            'view_id': False,
            'type': 'ir.actions.act_window',
            'domain': [('name', '=', self.ref)],
        }
