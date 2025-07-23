from odoo import fields, models, api, _
from datetime import date
from odoo.exceptions import UserError


class MofiContractTermination(models.Model):
    _name = 'mofi.contract.termination'
    _description = 'Contract Termination'

    contract_id = fields.Many2one('leasing.contract', string="Contract")
    termination_date = fields.Date(string="Termination Date")
    termination_note = fields.Text(string="Termination Note")

    @api.model
    def default_get(self, fields):
        res = super(MofiContractTermination, self).default_get(fields)
        if self._context.get('active_id'):
            res['contract_id'] = self._context.get('active_id')
            res['termination_date'] = self._context.get('termination_date')
        return res

    def button_process_termination(self):
        for rec in self.contract_id:
            date_check = rec.check_fiscalyear_date()
            lock_date = rec.check_journal_entries_lock_date()
            if lock_date and date_check and self.termination_date <= date_check:
                raise UserError('The journal entry date is on Lock Period. Please select another date.')
            else:
                context = {
                    'termination_date': self.termination_date,
                    'termination_note': self.termination_note
                }
                rec.with_context(context)._action_termination()
