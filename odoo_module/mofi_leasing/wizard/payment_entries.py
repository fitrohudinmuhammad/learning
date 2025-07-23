from odoo import fields, models, api
from datetime import date
from odoo.exceptions import UserError
import logging

_log = logging.getLogger(__name__)


class MofiPaymentEntries(models.TransientModel):
    _name = 'mofi.payment.entries'

    @api.model
    def default_get(self, fields):
        res = super(MofiPaymentEntries, self).default_get(fields)
        if self._context.get('active_id'):
            res['contract_id'] = self._context.get('active_id')
        return res

    contract_id = fields.Many2one(comodel_name='leasing.contract', string="Contract")
    journal_date = fields.Date(string="Journal Entry Date", default=fields.Date.context_today)

    def button_proceed_payment(self):
        _log.info('Process Generate Journal Payment')
        for rec in self.contract_id:
            date_check = self.contract_id.check_fiscalyear_date()
            lock_check = self.contract_id.check_journal_entries_lock_date()
            if lock_check and date_check and self.journal_date <= date_check:
                raise UserError('The journal entry date is on Lock Period. Please select another date.')
            else:
                # rec.with_context(journal_date=self.journal_date, date_check=True).create_payment_journal_entry()
                self.env.cr.execute("""SELECT generate_payment_lock_date(%s, '%s')""" % (self.contract_id.id, self.journal_date))
                self.env.cr.commit()
