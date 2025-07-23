from odoo import models, fields, _, api
from datetime import date
from odoo.exceptions import UserError
import logging

_log = logging.getLogger(__name__)


class MofiConfirmLockDateAmortization(models.TransientModel):
    _name = 'mofi.confirm.lock.date.amortization'
    _description = 'Confirm Lock Date Contract'

    contract_id = fields.Many2one(comodel_name='leasing.contract', string="Contract")
    amortization_id = fields.Many2one(comodel_name='mofi.leasing.amortization', string="Amortization")
    journal_date = fields.Date(string="Journal Entry Date", default=fields.Date.context_today)

    def button_proceed(self):
        _log.info('Process Generate Journal Amortization')
        if len(self._context.get('active_id')) == 1:
            amortization = self.amortization_id.browse(self._context.get('active_id')[0])
            date_check = amortization.check_fiscalyear_date()
            lock_check = amortization.check_journal_entries_lock_date()
            if lock_check and date_check and self.journal_date <= date_check:
                raise UserError('The journal entry date is on Lock Period. Please select another date.')
            else:
                amortization.button_calculate_amortization()
                self.env.cr.execute("""SELECT generate_amortization_journal_lock_date(%s, '%s')""" % (amortization.id, self.journal_date))
                self.env.cr.execute("""SELECT set_to_post_journal_amortization(%s)""" % (amortization.id))
                self.env.cr.commit()
                amortization.write({'status': 'active'})
        else:
            for rec in self._context.get('active_id'):
                amortization = self.amortization_id.browse(rec)
                if amortization.status == 'draft':
                    date_check = amortization.check_fiscalyear_date()
                    lock_check = amortization.check_journal_entries_lock_date()
                    if lock_check and date_check and self.journal_date <= date_check:
                        raise UserError('The journal entry date is on Lock Period. Please select another date.')
                    else:
                        amortization.button_calculate_amortization()
                        self.env.cr.execute("""SELECT generate_amortization_journal_lock_date(%s, '%s')""" % (amortization.id, self.journal_date))
                        self.env.cr.commit()
                        amortization.write({'status': 'active'})
