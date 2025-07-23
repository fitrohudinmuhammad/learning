from odoo import fields, models, api, _
from datetime import date
import logging
from odoo.exceptions import UserError


class MofiReverseAmortization(models.TransientModel):
    _name = 'mofi.reverse.amortization'

    @api.model
    def default_get(self, fields):
        res = super(MofiReverseAmortization, self).default_get(fields)
        if self._context.get('active_id'):
            res['amortization_id'] = self._context.get('active_id')
        return res

    date_mode = fields.Selection(selection=[
            ('custom', 'Specific'),
            ('entry', 'Journal Entry Date')
    ], required=True, default='custom')
    date = fields.Date(string='Reversal date', default=fields.Date.context_today)
    amortization_id = fields.Many2one(comodel_name='mofi.leasing.amortization', string="Amortization")

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
                    SELECT func_set_to_draft_amortization(%s);
                """ % (self.amortization_id.id))
            else:
                self.env.cr.execute("""
                    SELECT func_set_to_draft_amotization_with_date(%s, '%s');
                """ % (self.amortization_id.id, self.date))
        else:
            # lanjut
            logging.info('Yes')
            if self.date_mode == 'entry':
                self.env.cr.execute("""
                    SELECT func_set_to_draft_amortization(%s);
                """ % (self.amortization_id.id))
            else:
                self.env.cr.execute("""
                    SELECT func_set_to_draft_amotization_with_date(%s, '%s');
                """ % (self.amortization_id.id, self.date))
        
        self.amortization_id.write({'status': 'draft'})

    # def action_confirm(self):
    #     logging.info('Finish Set To Draft')
    #     return {
    #         'name': 'Confirm Set To Draft',
    #         'type': 'ir.actions.act_window',
    #         'res_model': 'confirm.reverse.date',
    #         'view_mode': 'form',
    #         'view_id': self.env.ref('mofi_leasing.view_confirm_reverse_date').id,
    #         'target': 'new',
    #         'context': {
    #             'default_contract_id': self.contract_id.id,
    #             'default_reverse_id': self.id,
    #             'default_date': self.date,
    #             'default_date_move': self.date_mode,
    #         },
    #     }