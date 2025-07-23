from odoo import fields, models, api, _
from datetime import date
import logging
from odoo.exceptions import UserError


class MofiReverseEntries(models.TransientModel):
    _name = 'mofi.reverse.entries'

    @api.model
    def default_get(self, fields):
        res = super(MofiReverseEntries, self).default_get(fields)
        if self._context.get('active_id'):
            res['contract_id'] = self._context.get('active_id')
        return res

    date_mode = fields.Selection(selection=[
            ('custom', 'Specific'),
            ('entry', 'Journal Entry Date')
    ], required=True, default='custom')
    date = fields.Date(string='Reversal date', default=fields.Date.context_today)
    contract_id = fields.Many2one(comodel_name='leasing.contract', string="Contract")

    def reverse_moves(self):
        logging.info('Start Set To Draft')
        # check lock date
        lock_date_ids = self.env['account.change.lock.date'].search(domain=[], order='id desc', limit=1)
        lock_date = None
        if lock_date_ids:
            # fiscalyear_lock_date
            # period_lock_date
            if lock_date_ids.period_lock_date and not lock_date_ids.fiscalyear_lock_date:
                lock_date = lock_date_ids.period_lock_date
            elif lock_date_ids.fiscalyear_lock_date and not lock_date_ids.period_lock_date:
                lock_date = lock_date_ids.fiscalyear_lock_date
            elif lock_date_ids.period_lock_date > lock_date_ids.fiscalyear_lock_date:
                lock_date = lock_date_ids.fiscalyear_lock_date
            elif lock_date_ids.period_lock_date < lock_date_ids.fiscalyear_lock_date:
                lock_date = lock_date_ids.period_lock_date
            elif lock_date_ids.period_lock_date == lock_date_ids.fiscalyear_lock_date:
                lock_date = lock_date_ids.period_lock_date
        if lock_date and lock_date > self.date:
            # tidak lanjut untuk pilih date lain
            logging.info('No')
            logging.info('Finish Set To Draft')
            raise UserError('The specific reversal date or journal entry date is on Lock Period. Please select another date.')
        elif lock_date and lock_date < self.date:
            # lanjut
            logging.info('Yes')
            if self.date_mode == 'entry':
                self.env.cr.execute("""
                    SELECT func_set_to_draft(%s);
                """ % (self.contract_id.id))
            else:
                self.env.cr.execute("""
                    SELECT func_set_to_draft_with_date(%s, '%s');
                """ % (self.contract_id.id, self.date))
        else:
            # lanjut
            logging.info('Yes')
            if self.date_mode == 'entry':
                self.env.cr.execute("""
                    SELECT func_set_to_draft(%s);
                """ % (self.contract_id.id))
            else:
                self.env.cr.execute("""
                    SELECT func_set_to_draft_with_date(%s, '%s');
                """ % (self.contract_id.id, self.date))
        self.contract_id.write({'status': 'draft'})
