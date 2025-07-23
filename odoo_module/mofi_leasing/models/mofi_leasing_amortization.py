from odoo import fields, models, api, _
from odoo.exceptions import UserError
from odoo.tools import float_compare
from datetime import date, datetime

import logging

_log = logging.getLogger(__name__)


class MofiLeasingAmortization(models.Model):
    _name = 'mofi.leasing.amortization'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _description = 'Leasing Amortization'
    _order = 'id desc'

    status = fields.Selection([
        ('draft', 'Draft'), ('active', 'Active'),
        ('close', 'Close'), ('cancel', 'Canceled')],
        default='draft',
        tracking=True,
        copy=False
    )
    name = fields.Char(
        string='Amortization',
        default=lambda self: _('New'),
        tracking=True)
    ca_contract_number_id = fields.Many2one(
        comodel_name='leasing.contract',
        string='Contract Number',
        tracking=True,
        copy=True)
    debtor_id = fields.Many2one('res.partner', string="Debtor", )
    fee_type_id = fields.Many2one('mofi.fee.type', string="Fee Type", )
    channel_id = fields.Many2one('mofi.channel', string="Channel")
    branch_id = fields.Many2one('mofi.branch', string="Branch")
    start_date = fields.Datetime(string="Start Date")
    end_date = fields.Datetime(string="End Date")
    amortization_line = fields.One2many(
        comodel_name='mofi.leasing.amortization.line',
        inverse_name='amortization_id',
        string="Amortization Line")
    company_id = fields.Many2one(
        'res.company',
        string="Company",
        default=lambda self: self.env.company,
        store=True,
        copy=True)
    currency_id = fields.Many2one(
        string="Currency", comodel_name='res.currency',
        default=lambda self: self.env.company.currency_id.id,
        copy=True
    )
    journal_entries_count = fields.Integer(
        string='Entries',
        compute='_compute_journal_entries_count')
    total_amount = fields.Monetary(string="Total Amount", )
    total_amortization_amount = fields.Monetary(string="Total", compute="_compute_total_amortization")

    termination_date = fields.Date(string='Termination Date')
    is_terminated = fields.Boolean(string='Is Terminated', default=False)



    def _compute_total_amortization(self):
        for line in self:
            line.total_amortization_amount = sum(line.amortization_line.mapped('amount'))

    def copy(self, default=None):
        '''inherit copy functionto add name in copy function
        so the name will be unique'''
        default = dict(default or {})
        if not default.get('name'):
            default['name'] = _("%s (copy)") % self.name
        return super().copy(default)

    def _prepare_create_amortization_line(self, amor_id, due_date, order_date, percen_accrual, amount):
        return {
            'amortization_id': amor_id,
            'due_date': due_date,
            'order_date': order_date,
            'percen_accrual': percen_accrual,
            'amount': amount
        }

    def button_calculate_amortization(self):
        """
        Function to calculate amortization for leasing contracts.
        """
        _log.info('execute function: button_calculate_amortization')
        contract = self.env['leasing.contract']
        amortization_lines = self.env['mofi.leasing.amortization.line']
        for rec in self:
            contract_id = contract.search([('id', '=', rec.ca_contract_number_id.id)], limit=1)
            existed_due_date = [dated.due_date for dated in rec.amortization_line]
            total_amount = rec.total_amount or 0.0

            for data in contract_id.interest_line:
                if data and data.due_date not in existed_due_date:
                    due_date = data.due_date
                    order_date = data.order_date
                    percen_accrual = data.percen_accrual
                    amount = (percen_accrual/100) * total_amount
                    amortization_lines.create(self._prepare_create_amortization_line(
                        amor_id=rec.id,
                        due_date=due_date,
                        order_date=order_date,
                        percen_accrual=percen_accrual,
                        amount=amount)
                    )
                else:
                    _log.info("Interest line not exist")

            if rec.amortization_line and rec.total_amortization_amount != rec.total_amount:
                total_amount = sum(line.amount for line in rec.amortization_line)
                hasil = rec.total_amount - total_amount

                amor_line = [line for line in rec.amortization_line]
                last_line = amor_line[-1]

                amor_adjust_line = self._prepare_create_amortization_line(
                                            amor_id=rec.id,
                                            due_date=last_line.due_date,
                                            order_date=last_line.order_date,
                                            percen_accrual=0.0,
                                            amount=hasil)
                amortization_lines.create(amor_adjust_line)

    def unlink_unposted_journal_entries(self):
        for rec in self.amortization_line:
            if rec.account_move_id.state == 'draft':
                rec.account_move_id.unlink()

    def _prepare_move(self, ref, contract, date, journal, auto_post):
        return {
            'ref': ref,
            'date': date,
            'journal_id': journal.id,
            'state': 'draft',
            'auto_post': auto_post,
            'contract_ref': contract,
            'amortization_ref': self.id
        }

    def _prepare_move_line(self, move_id, account, name, debit, credit, date, partner_id):
        move = {
            'move_id': move_id,
            'account_id': account.id,
            'name': name,
            'debit': debit,
            'credit': credit,
            'date': date,
            'partner_id': partner_id.id
        }
        return move

    def generate_journal_entries(self):
        """
        Generate journal entries for amortization lines and create corresponding account moves.
        """
        for rec in self:
            if not rec.amortization_line:
                raise UserError(_("No amortization lines found for contract: %s") % (rec.name))

            for amortization_line in rec.amortization_line.filtered(lambda a: not a.account_move_id):
                contract = rec.ca_contract_number_id.id
                fee_type = rec.fee_type_id
                journal = fee_type.amortization_account_journal_id
                create_date = rec.create_date.date()
                order_date = amortization_line.order_date.date() or create_date
                auto_post = 'no' if order_date < create_date else 'at_date'
                funding_type = rec.ca_contract_number_id.funding_type_id
                lease_account = self.env['mofi.leasing.account'].search([
                    ('channel_id', '=', rec.channel_id.id),
                    ('funding_type_id','=', funding_type.id),
                    ('fee_type_id', '=', fee_type.id),
                    ('journal_amortization_id', '=', journal.id),
                    ('active', '=', True),
                ])
                if not lease_account:
                    raise UserError(_("Journal Amortization Not Found for Fee type: %s, Channel: %s") % (fee_type.name, rec.channel_id.name))

                account_move = self.env['account.move'].create(
                    self._prepare_move(
                        ref=rec.name,
                        contract=contract,
                        date=amortization_line.order_date,
                        journal=journal,
                        auto_post=auto_post)
                )

                account_move_lines = []
                for lease in lease_account:
                    account_debit = lease.debit_account_amortization_id
                    account_credit = lease.credit_account_amortization_id
                    account_move_lines.append((0, 0, {
                        'move_id': account_move.id,
                        'account_id': account_debit.id,
                        'name': fee_type.name,
                        'debit': amortization_line.amount,
                        'credit': 0.0,
                        'partner_id': rec.debtor_id.id,
                    }))
                    account_move_lines.append((0, 0, {
                        'move_id': account_move.id,
                        'account_id': account_credit.id,
                        'name': fee_type.name,
                        'credit': amortization_line.amount,
                        'debit': 0.0,
                        'partner_id': rec.debtor_id.id,
                    }))

                account_move.write({'line_ids': account_move_lines})
                amortization_line.account_move_id = account_move.id

                if order_date < create_date:
                    account_move.action_post()
                account_move.write({'date': amortization_line.order_date})

    def generate_journal_entries_with_sql(self):
        _log.info("Generate Journal Entries with SQL")
        context = self._context.get('is_cron')
        for record in self:
            date_check = record.check_journal_entries_lock_date()
            date_journal = date.today()
            if context and not date_check:
                self.env.cr.execute("""SELECT generate_amortization_journal(%s)""" % (record.id))
                self.env.cr.commit()
            elif context and date_check:
                self.env.cr.execute("""SELECT generate_amortization_journal_lock_date(%s, '%s')""" % (record.id, date_journal))
                self.env.cr.execute("""SELECT set_to_post_journal_amortization(%s)""" % (record.id))
                self.env.cr.commit()
            elif not context and not date_check:
                self.env.cr.execute("""SELECT generate_amortization_journal(%s)""" % (record.id))
                self.env.cr.commit()
            elif not context and date_check:
                return {
                            'name': _('Generate Lock Date Amortization'),
                            'type': 'ir.actions.act_window',
                            'view_mode': 'form',
                            'res_model': 'mofi.confirm.lock.date.amortization',
                            'target': 'new',
                            'context': {
                                'active_id': self.ids
                            },
                            'view_id': self.env.ref('mofi_leasing.view_confirm_lock_date_amortization_wizard').id
                        }

    def check_fiscalyear_date(self):
        lock_date_ids = self.env['account.change.lock.date'].search(domain=[], order='id desc', limit=1)
        account_lock_date = self.env['account.change.lock.date'].search([])
        # fiscalyear_date = [dates.fiscalyear_lock_date for dates in account_lock_date if dates.fiscalyear_lock_date is not False]
        # periode_lock_date = [dates.periode_lock_date for dates in account_lock_date if dates.periode_lock_date is not False]
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
        return lock_date

    def check_journal_entries_lock_date(self):
        locks_date = self.check_fiscalyear_date() or False
        models_check = self.env['mofi.leasing.amortization.line']
        context = self.env.context
        date_check = False
        if locks_date:
            for rec in self:
                search_domain = [('amortization_id', '=', rec.id)]
                models_search = models_check.search(search_domain)
                for data in models_search:
                    if not data.account_move_id and data.order_date and data.order_date.date() < locks_date:
                        date_check = True
        return date_check

    def button_active(self):
        _log.info("button active clicked")
        context = self._context.get('is_cron')
        for record in self:
            record.button_calculate_amortization()
            date_check = record.check_journal_entries_lock_date()
            date_journal = date.today()
            if context and not date_check:
                self.env.cr.execute("""SELECT generate_amortization_journal(%s)""" % (record.id))
                self.env.cr.commit()
                record.button_active_no_calculate()
            elif context and date_check:
                self.env.cr.execute("""SELECT generate_amortization_journal_lock_date(%s, '%s')""" % (record.id, date_journal))
                self.env.cr.execute("""SELECT set_to_post_journal_amortization(%s)""" % (record.id))
                self.env.cr.commit()
                record.button_active_no_calculate()
            elif not context and not date_check:
                self.env.cr.execute("""SELECT generate_amortization_journal(%s)""" % (record.id))
                self.env.cr.commit()
                record.button_active_no_calculate()
            elif not context and date_check:
                return {
                            'name': _('Generate Lock Date Amortization'),
                            'type': 'ir.actions.act_window',
                            'view_mode': 'form',
                            'res_model': 'mofi.confirm.lock.date.amortization',
                            'target': 'new',
                            'context': {
                                'active_id': self.ids
                            },
                            'view_id': self.env.ref('mofi_leasing.view_confirm_lock_date_amortization_wizard').id
                        }

        # if len(self) == 1:
        #     if self.status != 'draft':
        #         _log.info("the status is active for %s", self.name)
        #     else:
        #         self.button_calculate_amortization()
        #         date_check = self.check_journal_entries_lock_date()
        #         if not date_check:
        #             _log.info("action active for %s", self.name)
        #             self.env.cr.execute("""SELECT generate_amortization_journal(%s)""" % (self.id))
        #             self.env.cr.commit()
        #             self.write({'status': 'active'})
        #         else:
        #             return {
        #                 'name': _('Generate Lock Date Amortization'),
        #                 'type': 'ir.actions.act_window',
        #                 'view_mode': 'form',
        #                 'res_model': 'mofi.confirm.lock.date.amortization',
        #                 'target': 'new',
        #                 'context': {
        #                     'active_id': self.ids
        #                 },
        #                 'view_id': self.env.ref('mofi_leasing.view_confirm_lock_date_amortization_wizard').id
        #             }
        # else:
        #     for data in self:
        #         if data.status != 'draft':
        #             _log.info("the status is active for %s", data.name)
        #         else:
        #             data.button_calculate_amortization()
        #             date_check = data.check_journal_entries_lock_date()
        #             if not date_check:
        #                 _log.info("action active for %s", data.name)
        #                 self.env.cr.execute("""SELECT generate_amortization_journal(%s)""" % (data.id))
        #                 self.env.cr.commit()
        #                 data.write({'status': 'active'})
        #             else:
                        # return {
                        #     'name': _('Generate Lock Date Amortization'),
                        #     'type': 'ir.actions.act_window',
                        #     'view_mode': 'form',
                        #     'res_model': 'mofi.confirm.lock.date.amortization',
                        #     'target': 'new',
                        #     'context': {
                        #         'active_id': self.ids
                        #     },
                        #     'view_id': self.env.ref('mofi_leasing.view_confirm_lock_date_amortization_wizard').id
                        # }
    def button_active_no_calculate(self):
        '''return to active state'''
        return self._action_active()

    def _action_active(self):
        return self.write({'status': 'active'})

    def button_draft(self):
        return self.write({'status': 'draft'})

    def button_close(self):
        return self.write({'status': 'close'})

    def button_cancel(self):
        return self.write({'status': 'cancel'})

    def action_journal_list(self):
        return {
            'name': _('Journal Entries'),
            'view_mode': 'tree,form',
            'res_model': 'account.move',
            'view_id': False,
            'type': 'ir.actions.act_window',
            'domain': [('amortization_ref', '=', self.id)],
        }

    def _compute_journal_entries_count(self):
        self.journal_entries_count = self.env['account.move'].search_count([('amortization_ref', '=', self.id)])

    def _action_run_active_amortization(self):
        _log.info("Activate Amortization")
        contracts = self.env['leasing.contract'].search([('status', '=', 'active')])

        _log.info("Contracts: %s" ,contracts)
        try:
            for contract in contracts:
                for loan in contract.contract_line:
                    interest = contract.interest_line.filtered(lambda i: i)
                    if not interest:
                        _log.info("No interest linked found for contract: %s" , contract.name)
                    else:
                        if loan.amortization and not loan.amortization_id:
                            _log.info("Generate ammortization for: %s" , contract.name)
                            contract.generate_amortization()

                    if loan.amortization_id.status == 'draft':
                        _log.info("Contract activating amortiation done for : %s" , contract.name)
                        loan.amortization_id.with_context(is_cron=True).button_active()
                    # else:
                #     _log.info("No interest linked found for contract: %s" % contract.name)
        except Exception as e:
            _log.info("Error: %s" , e)

    def _action_run_generate_amortization_entries(self):
        _log.info("Generate Amortization Entries start")
        amortization = self.env['mofi.leasing.amortization'].search([('status', '=', 'active')])

        try:
            for record in amortization:
                record.with_context(is_cron=True).generate_journal_entries_with_sql()
        except Exception as e:
            _log.warning("An Error Occures : %s" , e)


class MofiLeasingAmortizationLine(models.Model):
    """ amortization line"""
    _name = 'mofi.leasing.amortization.line'
    _description = 'Leasing Amortization Line'

    amortization_id = fields.Many2one('mofi.leasing.amortization')
    due_date = fields.Datetime(string="Due Date")
    order_date = fields.Datetime(string="Order Date")
    percen_accrual = fields.Float(string="% Based on Accrual")
    account_move_id = fields.Many2one('account.move', string="Journal")
    amount = fields.Monetary(string="Amount")
    company_id = fields.Many2one('res.company', string="Company",
                                 default=lambda self: self.env.company,
                                 store=True)
    currency_id = fields.Many2one(
        string="Currency", comodel_name='res.currency', default=lambda self: self.env.company.currency_id.id,
    )
