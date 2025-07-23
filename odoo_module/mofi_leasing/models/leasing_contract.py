from odoo.tools import (
    html_keep_url,
    is_html_empty,
)
from odoo import fields, models, _, api
from datetime import date, timedelta, datetime
from odoo.fields import Command
from itertools import groupby
from odoo.exceptions import UserError

import logging

_log = logging.getLogger(__name__)


class LeasingContract(models.Model):
    _name = "leasing.contract"
    _inherit = ["mail.thread", "mail.activity.mixin"]
    _description = "Leasing"
    _order = "id desc"

    status = fields.Selection(
        [
            ("draft", "Draft"),
            ("active", "Active"),
            ("close", "Close"),
            ("canceled", "Canceled"),
        ],
        default="draft",
        tracking=True,
        copy=False,
    )
    name = fields.Char(
        string="Contract Number",
        default=lambda self: _("New"),
        tracking=True,
        copy=False,
    )
    ca_contract_number_id = fields.Char(
        related="name", string="CA Contract Number", store=True, copy=False
    )
    debtor_id = fields.Many2one(
        "res.partner", string="Debtor", tracking=True, copy=True
    )
    funding_type_id = fields.Many2one(
        "mofi.funding.type", string="Funding Type", tracking=True, copy=True
    )
    channel_id = fields.Many2one(
        "mofi.channel", string="Channel", tracking=True, copy=True
    )
    loan_purpose_id = fields.Many2one(
        "mofi.loan.purpose", string="Loan Purpose", tracking=True, copy=True
    )
    is_restructure = fields.Boolean(string="Is Restructure", tracking=True, copy=True)
    branch_id = fields.Many2one(
        "mofi.branch", string="Branch", tracking=True, copy=True
    )
    start_date = fields.Datetime(string="Start Date", tracking=True, copy=True)
    end_date = fields.Datetime(string="End Date", tracking=True, copy=True)
    is_test = fields.Boolean(string="Is Test", tracking=True, copy=True)
    contract_line = fields.One2many(
        comodel_name="leasing.contract.line",
        inverse_name="contract_id",
        string="Contract Line",
        auto_join=True,
    )
    payment_line = fields.One2many(
        comodel_name="leasing.contract.payment",
        inverse_name="contract_id",
        string="Payment Line",
    )
    company_id = fields.Many2one(
        "res.company",
        string="Company",
        default=lambda self: self.env.company,
        store=True,
    )
    interest_line = fields.One2many(
        comodel_name="leasing.contract.interest",
        inverse_name="contract_id",
        string="Interest Line",
    )
    note = fields.Html(
        string="Terms and conditions",
        compute="_compute_note",
        store=True,
        readonly=False,
        precompute=True,
    )
    total_interest = fields.Monetary(
        string="Total Interest",
        compute="_compute_total_interest",
        tracking=True,
        copy=False,
    )
    currency_id = fields.Many2one(
        string="Currency",
        comodel_name="res.currency",
        default=lambda self: self.env.company.currency_id.id,
    )
    termination_date = fields.Date(string="Termination Date", tracking=True, copy=False)
    plat = fields.Char(string="Plat Number", tracking=True, copy=False)
    bpkb = fields.Char(string="BPKB Number", tracking=True, copy=False)
    mca_number = fields.Char(string="MCA Number", tracking=True, copy=True)

    journal_entries_count = fields.Integer(
        string="Entries", compute="_compute_journal_entries_count"
    )
    amortization_count = fields.Integer(
        string="Amortization", compute="_compute_amortization_count"
    )

    def _compute_amortization_count(self):
        self.amortization_count = 0
        mla = self.env["mofi.leasing.amortization"]
        amortization_count = mla.search([("ca_contract_number_id", "=", self.id)])
        if amortization_count:
            self.amortization_count = len(amortization_count) or 0

    def _compute_journal_entries_count(self):
        for record in self:
            record.journal_entries_count = 0
            je_count = self.env["account.move"].search(
                [("contract_ref", "=", record.name)]
            )
            if je_count:
                record.journal_entries_count = len(je_count) or 0

    @api.depends("debtor_id")
    def _compute_note(self):
        use_invoice_terms = (
            self.env["ir.config_parameter"]
            .sudo()
            .get_param("account.use_invoice_terms")
        )
        if not use_invoice_terms:
            return
        for order in self:
            order = order.with_company(order.company_id)
            if order.terms_type == "html" and self.env.company.invoice_terms_html:
                baseurl = html_keep_url(order._get_note_url() + "/terms")
                context = {"lang": order.partner_id.lang or self.env.user.lang}
                order.note = _("Terms & Conditions: %s", baseurl)
                del context
            elif not is_html_empty(self.env.company.invoice_terms):
                order.note = order.with_context(
                    lang=order.partner_id.lang
                ).env.company.invoice_terms

    def _compute_total_interest(self):
        for line in self:
            line.total_interest = sum(line.interest_line.mapped("total_accrual"))

    def copy_data(self, default=None):
        default = default or {}
        default.setdefault(
            "contract_line",
            [
                Command.create(line.copy_data()[0])
                for line in self.contract_line.filtered(lambda l: l.order_date)
            ],
        )
        default.setdefault(
            "payment_line",
            [
                Command.create(line.copy_data()[0])
                for line in self.payment_line.filtered(lambda l: l.order_date)
            ],
        )
        default.setdefault(
            "interest_line",
            [
                Command.create(line.copy_data()[0])
                for line in self.interest_line.filtered(lambda l: l.order_date)
            ],
        )
        return super().copy_data(default)

    def copy(self, default=None):
        default = dict(default or {})
        if not default.get("name"):
            default["name"] = _("%s (copy)") % self.name
        return super().copy(default)

    @api.model_create_multi
    def create(self, vals_list):
        contract_names = [val.get("name") for val in vals_list if "name" in val]
        contract_numbers = (
            self.env["leasing.contract"]
            .search([("status", "in", ["draft", "active", "close"])])
            .mapped("name")
        )
        if any(name in contract_numbers for name in contract_names):
            raise UserError(
                _(
                    "Duplicated contract number detected. You probably encoded twice the same contract."
                )
            )
        res = super(LeasingContract, self).create(vals_list)
        return res

    def write(self, vals):
        contract = self.env["leasing.contract"].search(
            [("status", "in", ["draft", "active", "close"])]
        )
        if any(rec.name == vals.get("name") for rec in contract):
            raise UserError(
                _(
                    "Duplicated contract number detected. You probably encoded twice the same contract."
                )
            )
        res = super(LeasingContract, self).write(vals)
        return res

    def action_amortization_list(self):
        return {
            "name": _("Amortization"),
            "view_mode": "tree,form",
            "res_model": "mofi.leasing.amortization",
            "view_id": False,
            "type": "ir.actions.act_window",
            "domain": [("ca_contract_number_id", "=", self.id)],
        }

    def action_journal_list(self):
        return {
            "name": _("Journal Entries"),
            "view_mode": "tree,form",
            "res_model": "account.move",
            "view_id": False,
            "type": "ir.actions.act_window",
            "domain": [("contract_ref", "=", self.name)],
        }

    def check_fiscalyear_date(self):
        lock_date_ids = self.env["account.change.lock.date"].search(
            domain=[], order="id desc", limit=1
        )
        account_lock_date = self.env["account.change.lock.date"].search([])
        # fiscalyear_date = [dates.fiscalyear_lock_date for dates in account_lock_date if dates.fiscalyear_lock_date is not False]
        # periode_lock_date = [dates.periode_lock_date for dates in account_lock_date if dates.periode_lock_date is not False]
        lock_date = None
        if lock_date_ids:
            # fiscalyear_lock_date
            # period_lock_date
            if (
                lock_date_ids.period_lock_date
                and not lock_date_ids.fiscalyear_lock_date
            ):
                lock_date = lock_date_ids.period_lock_date
            elif (
                lock_date_ids.fiscalyear_lock_date
                and not lock_date_ids.period_lock_date
            ):
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
        models_check = self.env["leasing.contract.line"]
        context = self.env.context
        if "payment" in context:
            models_check = self.env["leasing.contract.payment"]
        elif "interest" in context:
            models_check = self.env["leasing.contract.interest"]
        date_check = False
        if locks_date:
            search_domain = [("contract_id", "=", self.id)]
            models_search = models_check.search(search_domain)
            if "interest" in context:
                for data in models_search:
                    if (
                        not data.journal_account_move_id
                        or not data.eom_account_move_id
                        and data.order_date
                        and data.order_date.date() < locks_date
                    ):
                        date_check = True
            else:
                for data in models_search:
                    if (
                        not data.account_move_id
                        and data.order_date
                        and data.order_date.date() < locks_date
                    ):
                        date_check = True
        return date_check

    def button_active(self):
        """
        Checks if the button is active and performs certain actions based on the result.

        :return: Returns a dictionary with information about generating lock date entries or
                 writes the status of the record as "active".
        """
        _log.info("action active for %s", self.name)
        date_check = self.check_journal_entries_lock_date()
        for record in self:
            _log.info("action call loan entries for %s", record.name)
            _log.info("Date Check %s", date_check)
            if not date_check:
                self.env.cr.execute(
                    """SELECT generate_loan(%(id)s)""", {"id": record.id}
                )
                self.env.cr.execute(
                    """SELECT generate_payment(%(id)s)""", {"id": record.id}
                )
                self.env.cr.execute(
                    """SELECT generate_interest(%(id)s)""", {"id": record.id}
                )
                self.env.cr.commit()
                context = {"source": "orm", "contract_number": record.name, "filename": "Action Active Contract"}
                record.with_context(context).action_reconcile_loan_entries()
                record.with_context(context).action_reconcile_payment_entries()
                # record.generate_amortization()
                return record.write({"status": "active"})
            else:
                return {
                    "name": _("Generate Lock Date Entries"),
                    "type": "ir.actions.act_window",
                    "view_mode": "form",
                    "res_model": "mofi.confirm.lock.date",
                    "target": "new",
                    "context": {"active_id": self.id},
                    "view_id": self.env.ref(
                        "mofi_leasing.view_confirm_lock_date_wizard"
                    ).id,
                }

    def button_draft(self):
        return self.write({"status": "draft"})

    def button_close(self):
        mla = self.env["mofi.leasing.amortization"]
        for record in self:
            mla.search([("ca_contract_number_id", "=", record.id)]).write(
                {"status": "close"}
            )
            record.write({"status": "close"})

    def button_cancel(self):
        mla = self.env["mofi.leasing.amortization"]
        for record in self:
            mla.search([("ca_contract_number_id", "=", record.id)]).write(
                {"status": "cancel"}
            )
            record.write({"status": "canceled"})

    def button_termination(self):
        """
        button_termination method to handle termination of contracts.
        """
        termination = self.payment_line.filtered(lambda l: l.fee_type_id.is_termination)
        if not termination:
            raise UserError(_("No Termination Feetype is found!"))
        termite_date = termination.sorted(key=lambda t: t.order_date)
        termination_date = termite_date[-1].order_date if len(termite_date) > 1 else termination.order_date
        context = self.env.context.copy()
        context.update(
            {"active_id": self.id, "termination_date": termination_date}
        )
        return {
            "name": _("Termination Contract"),
            "type": "ir.actions.act_window",
            "view_mode": "form",
            "res_model": "mofi.contract.termination",
            "target": "new",
            "context": context,
            "view_id": self.env.ref(
                "mofi_leasing.view_contract_termination_wizard"
            ).id,
        }
        # for rec in self.payment_line.filtered(lambda l: l.fee_type_id.is_termination):
        #     termination = []
        #     if rec.fee_type_id.is_termination:
        #         termination += rec.fee_type_id
        #         # termination_date = rec.order_date
        #         if len(termination) > 1:
        #             termite_date = rec.sorted(key=lambda t: t.order_date)
        #             termination_date = termite_date[-1].order_date
        #         else:
        #             termination_date = rec.order_date
        #     else:
        #         # termination_date = date.today()
        #         raise UserError(_("No Termination Feetype is found!"))

        #     if termination:
        #         context = self.env.context.copy()
        #         context.update(
        #             {"active_id": self.id, "termination_date": termination_date}
        #         )
        #         return {
        #             "name": _("Termination Contract"),
        #             "type": "ir.actions.act_window",
        #             "view_mode": "form",
        #             "res_model": "mofi.contract.termination",
        #             "target": "new",
        #             "context": context,
        #             "view_id": self.env.ref(
        #                 "mofi_leasing.view_contract_termination_wizard"
        #             ).id,
        #         }

    def action_send_notification(self, message):
        for rec in self:
            mail_message = self.env["mail.message"].create(
                {
                    "model": "leasing.contract",
                    "subject": _("Notification of Contract Termination"),
                    "res_id": rec.id,
                    "message_type": "comment",
                    "subtype_id": self.env.ref("mail.mt_comment").id,
                    "body": message,
                    "email_from": self.env.user.email_formatted,
                    "author_id": self.env.user.id,
                    "date": fields.Datetime.now(),
                    "message_id": rec.id,
                    "partner_ids": rec.debtor_id.ids,
                }
            )
            mail_message.res_id = rec.id

    def _action_termination(self):
        context = self.env.context
        termination_date = context.get("termination_date")
        termination_note = context.get("termination_note")

        is_cron = self._context.get("is_cron")
        if is_cron:
            termination_date = date.today()
        for record in self:
            termination = []
            for info in record.contract_line:
                if info.fee_type_id.is_termination:
                    termination += info.fee_type_id

            for payment in record.payment_line:
                if payment.fee_type_id.is_termination:
                    termination += payment.fee_type_id

            for interest in record.interest_line:
                if interest.fee_type_id.is_termination:
                    termination += interest.fee_type_id

            if termination:
                amortization = self.env["mofi.leasing.amortization"].search(
                    [("ca_contract_number_id", "=", record.id)]
                )
                if not record.termination_date:
                    for interest in record.interest_line:
                        if (
                            interest.journal_account_move_id
                            and interest.journal_account_move_id.state == "draft"
                        ):
                            _log.info(
                                "delete account move: %s",
                                interest.journal_account_move_id,
                            )
                            interest.journal_account_move_id.unlink()
                        if (
                            interest.eom_account_move_id
                            and interest.eom_account_move_id.state == "draft"
                        ):
                            _log.info(
                                "delete account move: %s", interest.eom_account_move_id
                            )
                            interest.eom_account_move_id.unlink()
                        if (
                            not interest.journal_account_move_id
                            and not interest.eom_account_move_id
                        ):
                            interest.unlink()

                    for amortization_record in amortization:
                        closing_amortization = self.env["mofi.leasing.amortization"]
                        account_move = self.env["account.move"]
                        account_move_line = self.env["account.move.line"].with_context(
                            {"check_move_validity": False}
                        )
                        fee_type = amortization_record.fee_type_id
                        amount = amortization_record.total_amortization_amount
                        journal = (
                            amortization_record.fee_type_id.amortization_account_journal_id
                        )
                        create_date = record.create_date.date()
                        funding = record.funding_type_id.id
                        loan_purpose = record.loan_purpose_id.id
                        restructure = record.is_restructure
                        # flag on amortizatin
                        amortization_record.is_terminated = True
                        amortization_record.termination_date = termination_date
                        amortization_lines = self.env["mofi.leasing.amortization.line"]

                        line_amount = [
                            line.amount
                            for line in amortization_record.amortization_line.filtered(
                                lambda x: x.account_move_id.state == "draft"
                            )
                        ]
                        amount_post = [
                            lines.amount
                            for lines in amortization_record.amortization_line.filtered(
                                lambda x: x.account_move_id.state == "posted"
                            )
                        ]
                        # if line_amount > 0:
                        the_amounts = sum(line_amount)
                        post_amount = sum(amount_post)
                        # else:

                        total_amor_amount = amortization_record.total_amortization_amount
                        total_amount = amortization_record.total_amount

                        if the_amounts == 0:
                            the_amount = total_amount - post_amount
                        elif total_amount - the_amounts == 0:
                            the_amount = the_amounts
                        else:
                            the_amount = total_amount - post_amount

                        amor_adjust_line = (
                            amortization_record._prepare_create_amortization_line(
                                amor_id=amortization_record.id,
                                due_date=termination_date,
                                order_date=termination_date,
                                percen_accrual=0.0,
                                amount=the_amount,
                            )
                        )

                        amortization_line = amortization_lines.create(amor_adjust_line)

                        closing_amor_move = account_move.create(
                            amortization_record._prepare_move(
                                ref=amortization_record.name + "-" + "Termination",
                                contract=record.id,
                                journal=journal,
                                date=termination_date,
                                auto_post="no",
                            )
                        )
                        lease_account = self.env["mofi.leasing.account"].search(
                            [
                                ("channel_id", "=", amortization_record.channel_id.id),
                                ("fee_type_id", "=", fee_type.id),
                                ("funding_type_id", "=", funding),
                                ("loan_purpose_id", "=", loan_purpose),
                                ("is_restructure", "=", restructure),
                                ("journal_amortization_id", "=", journal.id),
                                ("active", "=", True),
                            ]
                        )
                        for lease in lease_account:
                            account_debit = lease.debit_account_amortization_id
                            account_credit = lease.credit_account_amortization_id

                            closing_amor_line_cr = amortization_record._prepare_move_line(
                                move_id=closing_amor_move.id,
                                account=account_credit,
                                date=False,
                                name=amortization_record.name + "-" + "Termination",
                                partner_id=amortization_record.debtor_id,
                                debit=0.0,
                                credit=the_amount,
                            )
                            closing_amor_line_db = (
                                amortization_record._prepare_move_line(
                                    move_id=closing_amor_move.id,
                                    account=account_debit,
                                    date=False,
                                    name=amortization_record.name + "-" + "Termination",
                                    partner_id=amortization_record.debtor_id,
                                    credit=0.0,
                                    debit=the_amount,
                                )
                            )
                            account_move_line.create(closing_amor_line_cr)
                            account_move_line.create(closing_amor_line_db)

                        _log.info(
                            "create account move: %s",
                            closing_amor_move.contract_ref.name,
                        )
                        _log.info("record name = %s", record.name)
                        if record.id == closing_amor_move.contract_ref.id:
                            closing_amor_move.action_post()
                            _log.info(
                                "Closing amortization move created: %s",
                                closing_amor_move.name,
                            )

                        if not amortization_line.account_move_id:
                            amortization_line.account_move_id = closing_amor_move.id

                        for line in amortization_record.amortization_line:
                            if line.account_move_id.state == "draft":
                                _log.info(
                                    "delete account move: %s", line.account_move_id.name
                                )
                                line.account_move_id.unlink()
                            if not line.account_move_id:
                                line.unlink()
                        amortization_record.button_close()
                    record.termination_date = termination_date
                    record.action_send_notification(termination_note)
                    record.button_close()

    def action_reconcile_loan_entries(self):
        ctx = self.env.context.copy()
        ctx.update({"no_exchange_difference": True})
        try:
            for rec in self:
                aml_to_reconcile = self.env["account.move.line"]
                second_aml_to_reconcile = self.env["account.move.line"]
                mla = self.env["mofi.leasing.account"]
                _log.info("reconcile loan entries: %s", rec.name)
                if rec.contract_line:
                    lease_account = mla.search(
                        [
                            ("funding_type_id", "=", rec.funding_type_id.id),
                            ("channel_id", "=", rec.channel_id.id),
                            ("loan_purpose_id", "=", rec.loan_purpose_id.id),
                            ("fee_type_id", "=", rec.contract_line[0].fee_type_id.id),
                            ("active", "=", True)
                        ],
                    )
                    for account in lease_account:
                        if (
                            account.debit_account_id.account_type == "liability_payable"
                            or account.credit_account_id.account_type
                            == "liability_payable"
                        ):
                            debit = account.debit_account_id
                            credit = account.credit_account_id
                            account_payable = debit if debit.account_type == "liability_payable" else credit

                        else:
                            _log.error("Payable account not found in Account %s", account.name)

                for loan in rec.contract_line:
                    if loan.account_move_id.state == "posted":
                        filtered = loan.account_move_id.line_ids.filtered(
                            lambda r: r.reconciled in (False, True)
                            and r.account_id.account_type == "liability_payable"
                        )
                        grouped_lines = groupby(
                            filtered.sorted(key=lambda r: r.account_id),
                            key=lambda r: r.account_id,
                        )
                        for account_id, lines in grouped_lines:
                            lines_to_reconcile = self.env[
                                "account.move.line"
                            ].concat(*lines)
                            if account_id.id:
                                aml_to_reconcile |= lines_to_reconcile
                            else:
                                second_aml_to_reconcile |= lines_to_reconcile

                for payment in rec.payment_line:
                    if payment.account_move_id.state == "posted":
                        payment_filtered = payment.account_move_id.line_ids.filtered(
                            lambda r: r.reconciled in (False, True) and not r.full_reconcile_id
                            and r.account_id.account_type == "liability_payable"
                        ).sorted(key=lambda r: r.date)
                        if len(payment_filtered.mapped("account_id")) == 1:
                            if aml_to_reconcile and payment_filtered.mapped(
                                "account_id"
                            ) == aml_to_reconcile.mapped("account_id"):
                                aml_to_reconcile |= payment_filtered
                            else:
                                second_aml_to_reconcile |= payment_filtered

                for interest in rec.interest_line:
                    if (
                        interest.eom_account_move_id
                        and interest.eom_account_move_id.state == "posted"
                    ):
                        interest_eom_filtered = (
                            interest.eom_account_move_id.line_ids.filtered(
                                lambda r: r.reconciled in (False, True) and not r.full_reconcile_id
                                and r.account_id.account_type == "liability_payable"
                            ).sorted(key=lambda r: r.date)
                        )
                        if len(interest_eom_filtered.mapped("account_id")) == 1:
                            if (
                                aml_to_reconcile
                                and interest_eom_filtered.mapped("account_id")[0]
                                == aml_to_reconcile.mapped("account_id")[0]
                            ):
                                aml_to_reconcile |= interest_eom_filtered
                            else:
                                second_aml_to_reconcile |= interest_eom_filtered
                    if (
                        interest.journal_account_move_id
                        and interest.journal_account_move_id.state == "posted"
                    ):
                        interest_journal_filtered = (
                            interest.journal_account_move_id.line_ids.filtered(
                                lambda r: r.reconciled in (False, True)
                                and r.account_id.account_type == "liability_payable"
                            ).sorted(key=lambda r: r.date)
                        )
                        if len(interest_journal_filtered.mapped("account_id")) == 1:
                            if (
                                aml_to_reconcile
                                and interest_journal_filtered.mapped("account_id")[0]
                                == aml_to_reconcile.mapped("account_id")[0]
                            ):
                                aml_to_reconcile |= interest_journal_filtered
                            else:
                                second_aml_to_reconcile |= interest_journal_filtered

                aml_to_reconcile += second_aml_to_reconcile
                aml_one = {}
                _log.info("%s", aml_to_reconcile)
                for rec in aml_to_reconcile.sorted(lambda m: m.account_id.id):
                    _log.info("%s", rec.account_id.name)
                    if rec.account_id.id not in aml_one:
                        aml_one[rec.account_id.id] = []
                    aml_one[rec.account_id.id].append(rec.id)

                for acc in aml_one:
                    debit = 0.0
                    credit = 0.0
                    moves_dbt = self.env['account.move.line']
                    moves_crd = self.env['account.move.line']
                    moves = self.env['account.move.line']
                    for aml in aml_one[acc]:
                        amls = self.env['account.move.line'].search([('id', '=', aml)])
                        debit += amls.debit
                        credit += amls.credit

                        amld = self.env['account.move.line'].search([('id', '=', aml), ('reconciled', '=', False)])
                        if amld.debit > 0.0:
                            moves_dbt |= amld
                        if amld.credit > 0.0:
                            moves_crd |= amld
                        moves |= amls
                    _log.info("debit: %s", debit)
                    _log.info("credit: %s", credit)
                    if debit > 0.0 and credit > 0.0:
                        # debit
                        if debit != credit:
                            _log.info("move debit: %s", moves_dbt)
                            _log.info("move credit: %s", moves_crd)
                            if debit > credit:
                                _log.info('Debit > Credit')
                                for crd in moves_crd:
                                    total = 0.0
                                    for dbt in moves_dbt.filtered(lambda r: not r.reconciled).sorted('debit'):
                                        partial = self.env['account.partial.reconcile'].search([('credit_move_id', '=', crd.id)])
                                        dbt_partial = self.env['account.partial.reconcile'].search([('debit_move_id', '=', dbt.id)])
                                        if not partial:
                                            if dbt_partial:
                                                if (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))) > crd.credit:
                                                    total = crd.credit
                                                    rec = False
                                                elif (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))) < crd.credit:
                                                    total = dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))
                                                    rec = True
                                                else:
                                                    total = crd.credit
                                                    rec = True
                                            else:
                                                if dbt.debit < crd.credit:
                                                    total = dbt.debit
                                                    rec = True
                                                elif dbt.debit == crd.credit:
                                                    total = crd.credit
                                                    rec = True
                                                else:
                                                    total = crd.credit
                                                    rec = False

                                            self.env['account.partial.reconcile'].create({
                                                'amount': total,
                                                'debit_amount_currency': total,
                                                'credit_amount_currency': total,
                                                'debit_move_id': dbt.id,
                                                'credit_move_id': crd.id,
                                            })
                                            crd.write({
                                                'matching_number': 'P',
                                                'reconciled': True
                                            })
                                            dbt.write({
                                                'matching_number': 'P',
                                                'reconciled': rec
                                            })
                                            if dbt_partial:
                                                if (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))) < crd.credit:
                                                    total = crd.credit - (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency')))
                                                elif (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))) > crd.credit:
                                                    total = (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))) - crd.credit
                                                else:
                                                    total = 0.0
                                            else:
                                                if dbt.debit > crd.credit:
                                                    total = crd.credit - dbt.debit
                                                elif dbt.debit < crd.credit:
                                                    total = crd.credit - dbt.debit
                                                else:
                                                    total = 0.0
                                        else:
                                            if total != 0.0 and total > 0.0:
                                                self.env['account.partial.reconcile'].create({
                                                    'amount': total,
                                                    'debit_amount_currency': total,
                                                    'credit_amount_currency': total,
                                                    'debit_move_id': dbt.id,
                                                    'credit_move_id': crd.id,
                                                })
                                                crd.write({
                                                    'matching_number': 'P',
                                                    'reconciled': True
                                                })
                                                dbt.write({'matching_number': 'P'})
                                                if dbt.debit >= total:
                                                    total = 0.0
                                                else:
                                                    total -= dbt.debit
                                            else:
                                                dbt.write({'matching_number': 'P'})
                            elif debit < credit:
                                _log.info('Debit < Credit')
                                for dbt in moves_dbt:
                                    total = 0.0
                                    for crd in moves_crd.filtered(lambda r: not r.reconciled).sorted('credit'):
                                        partial = self.env['account.partial.reconcile'].search([('debit_move_id', '=', dbt.id)])
                                        crd_partial = self.env['account.partial.reconcile'].search([('credit_move_id', '=', crd.id)])
                                        if not partial:
                                            if crd_partial:
                                                if (crd.credit - sum(crd_partial.mapped('credit_amount_currency'))) > dbt.debit:
                                                    total = dbt.debit
                                                    rec = False
                                                elif (crd.credit - sum(crd_partial.mapped('credit_amount_currency'))) < dbt.debit:
                                                    total = crd.credit - sum(crd_partial.mapped('credit_amount_currency'))
                                                    rec = True
                                                else:
                                                    total = dbt.debit
                                                    rec = True
                                            else:
                                                if dbt.debit > crd.credit:
                                                    total = crd.credit
                                                    rec = True
                                                elif dbt.debit == crd.credit:
                                                    total = dbt.debit
                                                    rec = True
                                                else:
                                                    total = dbt.debit
                                                    rec = False
                                            self.env['account.partial.reconcile'].create({
                                                'amount': total,
                                                'debit_amount_currency': total,
                                                'credit_amount_currency': total,
                                                'debit_move_id': dbt.id,
                                                'credit_move_id': crd.id,
                                            })
                                            dbt.write({
                                                'matching_number': 'P',
                                                'reconciled': True
                                            })
                                            crd.write({
                                                'matching_number': 'P',
                                                'reconciled': rec
                                            })
                                            if crd_partial:
                                                if (crd.credit - sum(crd_partial.mapped('credit_amount_currency'))) < dbt.debit:
                                                    total = dbt.debit - (crd.credit - sum(crd_partial.mapped('credit_amount_currency')))
                                                elif (crd.credit - sum(crd_partial.mapped('credit_amount_currency'))) > dbt.debit:
                                                    total = (crd.credit - sum(crd_partial.mapped('credit_amount_currency'))) - dbt.debit
                                                else:
                                                    total = 0.0
                                            else:
                                                if dbt.debit > crd.credit:
                                                    total = dbt.debit - crd.credit
                                                elif dbt.debit < crd.credit:
                                                    total = dbt.debit - crd.credit
                                                else:
                                                    total = 0.0
                                        else:
                                            if total != 0.0 and total > 0.0:
                                                self.env['account.partial.reconcile'].create({
                                                    'amount': total,
                                                    'debit_amount_currency': total,
                                                    'credit_amount_currency': total,
                                                    'debit_move_id': dbt.id,
                                                    'credit_move_id': crd.id,
                                                })
                                                dbt.write({
                                                    'matching_number': 'P',
                                                    'reconciled': True
                                                })
                                                crd.write({'matching_number': 'P'})
                                                if crd.credit >= total:
                                                    total = 0.0
                                                else:
                                                    total -= crd.credit
                                            else:
                                                crd.write({'matching_number': 'P'})
                        else:
                            _log.info('Debit = Credit')
                            try:
                                moves.with_context(no_exchange_difference=True).reconcile()
                                for mv in moves:
                                    mv.write({'amount_residual': mv.balance})
                                moves.with_context(no_exchange_difference=True).reconcile()
                                for mv in moves:
                                    mv.write({'reconciled': True})
                            except Exception as e:
                                involved_partials = moves.filtered(lambda r: not r.reconciled).matched_credit_ids | moves.filtered(lambda r: not r.reconciled).matched_debit_ids
                                self.env['account.full.reconcile'] \
                                .with_context(
                                    skip_invoice_sync=True,
                                    skip_invoice_line_sync=True,
                                    skip_account_move_synchronization=True,
                                    check_move_validity=False,
                                ) \
                                .create({
                                    'partial_reconcile_ids': [Command.set(involved_partials.ids)],
                                    'reconciled_line_ids': [Command.set(moves.ids)],
                                })
                                moves.write({'reconciled': True})
            _log.info("Reconcile Loan Entries Successfully")
        except Exception as e:
            name = "ERROR: Reconcile %s" % ctx.get("contract_number")
            desc = "Error while Reconcile Loan Entries: %s" % e
            filename = ctx.get("filename") or ""
            if ctx.get("source") and ctx.get("source") == "orm":
                _log.error("Error while Reconcile Loan Entries: %s" % e)
                self.env.cr.execute("""
                    INSERT INTO logging_integration(name, filename, description, log_time, error_status, create_uid, create_date, write_uid, write_date, active)
                    VALUES ('%s', '%s', '%s', now() at time zone 'utc', true, %s, now() at time zone 'utc', %s, now() at time zone 'utc', true)
                """ % (name, filename, desc, self.env.uid, self.env.uid))
                self.env.cr.commit()
                raise UserError("Error while Reconcile Loan Entries: %s" % e)
            else:
                self.env.cr.execute("""
                    INSERT INTO logging_integration(name, filename, description, log_time, error_status, create_uid, create_date, write_uid, write_date, active)
                    VALUES ('%s', '%s', '%s', now() at time zone 'utc', true, %s, now() at time zone 'utc', %s, now() at time zone 'utc', true)
                """ % (name, filename, desc, self.env.uid, self.env.uid))
                self.env.cr.commit()
                _log.error("Error while Reconcile Loan Entries: %s" % e)

    def action_reconcile_payment_entries(self):
        ctx = self.env.context.copy()
        ctx.update({"no_exchange_difference": True,})
        try:
            for rec in self:
                aml_to_reconcile = self.env["account.move.line"]
                aml_to_reconcile_two = self.env["account.move.line"]
                mla = self.env["mofi.leasing.account"]
                _log.info("reconcile payment entries: %s", rec.name)
                if rec.contract_line:
                    lease_account = mla.search(
                        [
                            ("funding_type_id", "=", rec.funding_type_id.id),
                            ("channel_id", "=", rec.channel_id.id),
                            ("loan_purpose_id", "=", rec.loan_purpose_id.id),
                            ("fee_type_id", "=", rec.contract_line[0].fee_type_id.id),
                            ("active", "=", True)
                        ],
                    )

                    for account in lease_account:
                        if (
                            account.debit_account_id.account_type == "asset_receivable"
                            or account.credit_account_id.account_type
                            == "asset_receivable"
                        ):
                            debit = account.debit_account_id
                            credit = account.credit_account_id
                            account_receivable = debit if debit.account_type == "asset_receivable" else credit
                        else:
                            _log.error("Receivable account not found in Account %s", account.name)

                for loan in rec.contract_line:
                    if loan.account_move_id.state == "posted":
                        loan_filtered = loan.account_move_id.line_ids.filtered(
                            lambda r: r.reconciled in (False, True) and not r.full_reconcile_id
                            and r.account_id.account_type == "asset_receivable"
                        ).sorted(key=lambda r: r.date)
                        grouped_lines = groupby(
                            loan_filtered.sorted(key=lambda r: r.account_id),
                            key=lambda r: r.account_id,
                        )
                        for account_id, lines in grouped_lines:
                            lines_to_reconcile = self.env[
                                "account.move.line"
                            ].concat(*lines)
                            if account_id.id:
                                aml_to_reconcile |= lines_to_reconcile
                            else:
                                aml_to_reconcile_two |= lines_to_reconcile

                for payment in rec.payment_line:
                    if payment.account_move_id.state == "posted":
                        payment_filtered = payment.account_move_id.line_ids.filtered(
                            lambda r: r.reconciled in (False, True) and not r.full_reconcile_id
                            and r.account_id.account_type == "asset_receivable"
                        ).sorted(key=lambda r: r.date)
                        if len(payment_filtered.mapped("account_id")) == 1:
                            if aml_to_reconcile and payment_filtered.mapped(
                                "account_id"
                            ) == aml_to_reconcile.mapped("account_id"):
                                aml_to_reconcile |= payment_filtered
                            else:
                                aml_to_reconcile_two |= payment_filtered

                for interest in rec.interest_line:
                    if (
                        interest.eom_account_move_id
                        and interest.eom_account_move_id.state == "posted"
                    ):
                        interest_eom_filtered = (
                            interest.eom_account_move_id.line_ids.filtered(
                                lambda r: r.reconciled in (False, True) and not r.full_reconcile_id
                                and r.account_id.account_type == "asset_receivable"
                            ).sorted(key=lambda r: r.date)
                        )
                        if len(interest_eom_filtered.mapped("account_id")) == 1:
                            if (
                                aml_to_reconcile
                                and interest_eom_filtered.mapped("account_id")[0]
                                == aml_to_reconcile.mapped("account_id")[0]
                            ):
                                aml_to_reconcile |= interest_eom_filtered
                            else:
                                aml_to_reconcile_two |= interest_eom_filtered
                    if (
                        interest.journal_account_move_id
                        and interest.journal_account_move_id.state == "posted"
                    ):
                        interest_journal_filtered = (
                            interest.journal_account_move_id.line_ids.filtered(
                                lambda r: r.reconciled in (False, True)
                                and r.account_id.account_type == "asset_receivable"
                            ).sorted(key=lambda r: r.date)
                        )
                        if len(interest_journal_filtered.mapped("account_id")) == 1:
                            if (
                                aml_to_reconcile
                                and interest_journal_filtered.mapped("account_id")[0]
                                == aml_to_reconcile.mapped("account_id")[0]
                            ):
                                aml_to_reconcile |= interest_journal_filtered
                            else:
                                aml_to_reconcile_two |= interest_journal_filtered

                aml_to_reconcile += aml_to_reconcile_two
                aml_to_reconcile.sorted(key=lambda r: r.date)
                aml_one = {}
                _log.info('%s', aml_to_reconcile)
                for rec in aml_to_reconcile.sorted(lambda m: m.account_id.id):
                    _log.info('%s', rec.account_id.name)
                    if rec.account_id.id not in aml_one:
                        aml_one[rec.account_id.id] = []
                    aml_one[rec.account_id.id].append(rec.id)

                for acc in aml_one:
                    debit = 0.0
                    credit = 0.0
                    moves_dbt = self.env['account.move.line']
                    moves_crd = self.env['account.move.line']
                    moves = self.env['account.move.line']
                    for aml in aml_one[acc]:
                        amls = self.env['account.move.line'].search([('id', '=', aml)])
                        debit += amls.debit
                        credit += amls.credit
                        moves |= amls

                        amld = self.env['account.move.line'].search([('id', '=', aml), ('reconciled', '=', False)])
                        if amld.debit > 0.0:
                            moves_dbt |= amld
                        if amld.credit > 0.0:
                            moves_crd |= amld

                    _log.info('debit: %s', debit)
                    _log.info('credit: %s', credit)
                    if debit > 0.0 and credit > 0.0:
                        # debit
                        if debit != credit:
                            _log.info('move debit: %s', moves_dbt)
                            _log.info('move credit: %s', moves_crd)
                            if debit > credit:
                                _log.info('Debit > Credit')
                                for crd in moves_crd:
                                    total = 0.0
                                    for dbt in moves_dbt.filtered(lambda r: not r.reconciled).sorted('debit'):
                                        partial = self.env['account.partial.reconcile'].search([('credit_move_id', '=', crd.id)])
                                        dbt_partial = self.env['account.partial.reconcile'].search([('debit_move_id', '=', dbt.id)])
                                        if not partial:
                                            if dbt_partial:
                                                if (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))) > crd.credit:
                                                    total = crd.credit
                                                    rec = False
                                                elif (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))) < crd.credit:
                                                    total = dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))
                                                    rec = True
                                                else:
                                                    total = crd.credit
                                                    rec = True
                                            else:
                                                if dbt.debit < crd.credit:
                                                    total = dbt.debit
                                                    rec = True
                                                elif dbt.debit == crd.credit:
                                                    total = crd.credit
                                                    rec = True
                                                else:
                                                    total = crd.credit
                                                    rec = False

                                            self.env['account.partial.reconcile'].create({
                                                'amount': total,
                                                'debit_amount_currency': total,
                                                'credit_amount_currency': total,
                                                'debit_move_id': dbt.id,
                                                'credit_move_id': crd.id,
                                            })
                                            crd.write({
                                                'matching_number': 'P',
                                                'reconciled': True
                                            })
                                            dbt.write({
                                                'matching_number': 'P',
                                                'reconciled': rec
                                            })
                                            if dbt_partial:
                                                if (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))) < crd.credit:
                                                    total = crd.credit - (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency')))
                                                elif (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))) > crd.credit:
                                                    total = (dbt.debit - sum(dbt_partial.mapped('debit_amount_currency'))) - crd.credit
                                                else:
                                                    total = 0.0
                                            else:
                                                if dbt.debit > crd.credit:
                                                    total = crd.credit - dbt.debit
                                                elif dbt.debit < crd.credit:
                                                    total = crd.credit - dbt.debit
                                                else:
                                                    total = 0.0
                                        else:
                                            if total != 0.0 and total > 0.0:
                                                self.env['account.partial.reconcile'].create({
                                                    'amount': total,
                                                    'debit_amount_currency': total,
                                                    'credit_amount_currency': total,
                                                    'debit_move_id': dbt.id,
                                                    'credit_move_id': crd.id,
                                                })
                                                crd.write({
                                                    'matching_number': 'P',
                                                    'reconciled': True
                                                })
                                                dbt.write({'matching_number': 'P',})
                                                if dbt.debit >= total:
                                                    total = 0.0
                                                else:
                                                    total -= dbt.debit
                                            else:
                                                dbt.write({
                                                    'matching_number': 'P'
                                                })
                            elif debit < credit:
                                _log.info('Debit < Credit')
                                for dbt in moves_dbt:
                                    total = 0.0
                                    for crd in moves_crd.filtered(lambda r: not r.reconciled).sorted('credit'):
                                        partial = self.env['account.partial.reconcile'].search([('debit_move_id', '=', dbt.id)])
                                        crd_partial = self.env['account.partial.reconcile'].search([('credit_move_id', '=', crd.id)])
                                        if not partial:
                                            if crd_partial:
                                                if (crd.credit - sum(crd_partial.mapped('credit_amount_currency'))) > dbt.debit:
                                                    total = dbt.debit
                                                    rec = False
                                                elif (crd.credit - sum(crd_partial.mapped('credit_amount_currency'))) < dbt.debit:
                                                    total = crd.credit - sum(crd_partial.mapped('credit_amount_currency'))
                                                    rec = True
                                                else:
                                                    total = dbt.debit
                                                    rec = True
                                            else:
                                                if dbt.debit > crd.credit:
                                                    total = crd.credit
                                                    rec = True
                                                elif dbt.debit == crd.credit:
                                                    total = dbt.debit
                                                    rec = True
                                                else:
                                                    total = dbt.debit
                                                    rec = False
                                            self.env['account.partial.reconcile'].create({
                                                'amount': total,
                                                'debit_amount_currency': total,
                                                'credit_amount_currency': total,
                                                'debit_move_id': dbt.id,
                                                'credit_move_id': crd.id,
                                            })
                                            dbt.write({
                                                'matching_number': 'P',
                                                'reconciled': True
                                            })
                                            crd.write({
                                                'matching_number': 'P',
                                                'reconciled': rec
                                            })
                                            if crd_partial:
                                                if (crd.credit - sum(crd_partial.mapped('credit_amount_currency'))) < dbt.debit:
                                                    total = dbt.debit - (crd.credit - sum(crd_partial.mapped('credit_amount_currency')))
                                                elif (crd.credit - sum(crd_partial.mapped('credit_amount_currency'))) > dbt.debit:
                                                    total = (crd.credit - sum(crd_partial.mapped('credit_amount_currency'))) - dbt.debit
                                                else:
                                                    total = 0.0
                                            else:
                                                if dbt.debit > crd.credit:
                                                    total = dbt.debit - crd.credit
                                                elif dbt.debit < crd.credit:
                                                    total = dbt.debit - crd.credit
                                                else:
                                                    total = 0.0
                                        else:
                                            if total != 0.0 and total > 0.0:
                                                self.env['account.partial.reconcile'].create({
                                                    'amount': total,
                                                    'debit_amount_currency': total,
                                                    'credit_amount_currency': total,
                                                    'debit_move_id': dbt.id,
                                                    'credit_move_id': crd.id,
                                                })
                                                dbt.write({
                                                    'matching_number': 'P',
                                                    'reconciled': True
                                                })
                                                crd.write({'matching_number': 'P',})
                                                if crd.credit >= total:
                                                    total = 0.0
                                                else:
                                                    total -= crd.credit
                                            else:
                                                crd.write({
                                                    'matching_number': 'P'
                                                })
                        else:
                            _log.info('Debit = Credit')
                            try:
                                moves.with_context(no_exchange_difference=True).reconcile()
                                for mv in moves:
                                    mv.write({'amount_residual': mv.balance})
                                moves.with_context(no_exchange_difference=True).reconcile()
                                for mv in moves:
                                    mv.write({
                                        'reconciled': True
                                    })
                            except Exception as e:
                                involved_partials = moves.filtered(lambda r: not r.reconciled).matched_credit_ids | moves.filtered(lambda r: not r.reconciled).matched_debit_ids
                                self.env['account.full.reconcile'] \
                                .with_context(
                                    skip_invoice_sync=True,
                                    skip_invoice_line_sync=True,
                                    skip_account_move_synchronization=True,
                                    check_move_validity=False,
                                ) \
                                .create({
                                    'partial_reconcile_ids': [Command.set(involved_partials.ids)],
                                    'reconciled_line_ids': [Command.set(moves.ids)],
                                })
                                moves.write({'reconciled': True})
            _log.info("Reconcile Payment Entries Successfully")
        except Exception as e:
            name = "ERROR: Reconcile %s" % ctx.get("contract_number")
            desc = "Error while Reconcile Payment Entries: %s" % e
            filename = ctx.get("filename") or ""
            if ctx.get("source") and ctx.get("source") == "orm":
                _log.error("Error while Reconcile Payment Entries: %s ", e)
                self.env.cr.execute("""
                    INSERT INTO logging_integration(name, filename, description, log_time, error_status, create_uid, create_date, write_uid, write_date, active)
                    VALUES ('%s', '%s', '%s', now() at time zone 'utc', true, %s, now() at time zone 'utc', %s, now() at time zone 'utc', true)
                """ % (name, filename, desc, self.env.uid, self.env.uid))
                self.env.cr.commit()
                raise UserError("Error while Reconcile Payment Entries: %s " % e)
            else:
                self.env.cr.execute("""
                    INSERT INTO logging_integration(name, filename, description, log_time, error_status, create_uid, create_date, write_uid, write_date, active)
                    VALUES ('%s', '%s', '%s', now() at time zone 'utc', true, %s, now() at time zone 'utc', %s, now() at time zone 'utc', true)
                """ % (name, filename, desc, self.env.uid, self.env.uid))
                self.env.cr.commit()
                _log.error("Error while Reconcile Payment Entries: %s ", e)

    def check_journal_entries_exist(self, ref, journal_id):
        am = self.env["account.move"].search(
            [("ref", "=", ref), ("journal_id", "=", journal_id)]
        )
        return True if am else False

    def call_payment_entries_wizard(self):
        _log.info("Generate payment entries")
        date_check = self.with_context(payment=True).check_journal_entries_lock_date()
        for rec in self:
            if not rec.payment_line:
                raise UserError(
                    "No Payment Line, please check again for Contract %s " % (rec.name)
                )
            for line in rec.payment_line:
                lease_account = self.env["mofi.leasing.account"].search(
                    [
                        ("funding_type_id", "=", rec.funding_type_id.id),
                        ("channel_id", "=", rec.channel_id.id),
                        ("loan_purpose_id", "=", rec.loan_purpose_id.id),
                        ("is_restructure", "=", rec.is_restructure),
                        ("fee_type_id", "=", line.fee_type_id.id),
                        ("active", "=", True),
                    ]
                )

                if lease_account:
                    if not date_check:
                        if line and not line.account_move_id:
                            _log.info(
                                "No Lock date -> continue create payment journal entry"
                            )
                            self.env.cr.execute(
                                """SELECT generate_payment(%(id)s);""", {"id": rec.id}
                            )
                            self.env.cr.commit()
                            _log.info(
                                "Payment journal entry created, reconcile payment entries"
                            )
                            # self.action_reconcile_payment_entries()
                    else:
                        return {
                            "name": _("Generate Payment Entries"),
                            "type": "ir.actions.act_window",
                            "view_mode": "form",
                            "res_model": "mofi.payment.entries",
                            "target": "new",
                            "context": {"active_id": self.id},
                            "view_id": self.env.ref(
                                "mofi_leasing.view_payment_entries_wizard"
                            ).id,
                        }

    def call_interest_entries_wizard(self):
        _log.info("Call Interest Entries Wizard")
        date_check = self.with_context(interest=True).check_journal_entries_lock_date()
        for rec in self:
            if not rec.interest_line:
                raise UserError(
                    "No Interest Line, please check again for Contract %s " % (rec.name)
                )

            for line in rec.interest_line:
                lease_account = self.env["mofi.leasing.account"].search(
                    [
                        ("funding_type_id", "=", rec.funding_type_id.id),
                        ("channel_id", "=", rec.channel_id.id),
                        ("loan_purpose_id", "=", rec.loan_purpose_id.id),
                        ("is_restructure", "=", rec.is_restructure),
                        ("fee_type_id", "=", line.fee_type_id.id),
                        ("active", "=", True),
                    ]
                )

                if lease_account:
                    if not date_check:
                        if (
                            line
                            and not line.eom_account_move_id
                            or not line.journal_account_move_id
                        ):
                            # self.create_interest_journal_entry()
                            _log.info(
                                "Generate Entries for Payment on Contract %s ", rec.name
                            )
                            self.env.cr.execute(
                                """SELECT generate_interest(%s)""" % (rec.id)
                            )
                            self.env.cr.commit()
                    else:
                        return {
                            "name": _("Generate Interest Entries"),
                            "type": "ir.actions.act_window",
                            "view_mode": "form",
                            "res_model": "mofi.interest.entries",
                            "target": "new",
                            "context": {"active_id": self.id},
                            "view_id": self.env.ref(
                                "mofi_leasing.view_interest_entries_wizard"
                            ).id,
                        }

    def _calculate_percen_accrual(self):
        for rec in self:
            _log.info("calculate percen acrual for %s ", rec.name)
            sum_accrual = rec.total_interest
            for interest in rec.interest_line:
                accrual_amount = interest.total_accrual
                interest.percen_accrual = (accrual_amount / sum_accrual) * 100

    def generate_amortization(self):
        """
        Generates the amortization schedule for each record in the current recordset.

        This function iterates over each record in the current recordset and calculates
        the percentage accrual for each record by calling the `_calculate_percen_accrual` method.
        Then, it iterates over each `contract_line` associated with the current record and checks
        if an `amortization_id` is already assigned. If not, it generates a new amortization record.

        The amortization record is created with the following values:

        - `name`: The concatenation of the current record's name and the fee type name associated with the `contract_line`.
        - `status`: "draft"
        - `ca_contract_number_id`: The ID of the current record.
        - `debtor_id`: The ID of the debtor associated with the current record.
        - `fee_type_id`: The ID of the fee type associated with the `contract_line`.
        - `channel_id`: The ID of the channel associated with the current record.
        - `branch_id`: The ID of the branch associated with the current record.
        - `total_amount`: The amount from the `contract_line`.
        - `start_date`: The start date of the current record.
        - `end_date`: The end date of the current record.

        The newly created amortization record is then assigned to the `amortization_id` field of the `contract_line`.
        """

        for rec in self:
            _log.info("Generate Amortization for Contract %s", rec.name)

            try:
                rec._calculate_percen_accrual()
                for info in rec.contract_line:
                    if not info.amortization_id:
                        amortization_name = rec.name + " - " + info.fee_type_id.name
                        amortization_vals = []
                        if info.amortization:
                            vals = {
                                "name": amortization_name,
                                "status": "draft",
                                "ca_contract_number_id": rec.id,
                                "debtor_id": rec.debtor_id.id,
                                "fee_type_id": info.fee_type_id.id,
                                "channel_id": rec.channel_id.id,
                                "branch_id": rec.branch_id.id,
                                "total_amount": info.amount,
                                "start_date": rec.start_date,
                                "end_date": rec.end_date,
                            }
                            amortization_vals.append(vals)
                            amortization = self.env["mofi.leasing.amortization"].create(
                                amortization_vals
                            )
                            info.amortization_id = amortization.id
                _log.info("Generate amortization done")
            except UserError as e:
                raise UserError(
                    "Exception: %s \n Please check the amortization data for the current Contract", e
                )

    def _prepare_move_line(self, move_id, account, debit, credit, date):
        return {
            "move_id": move_id,
            "account_id": account.id,
            "debit": debit,
            "credit": credit,
            "due_date": date,
        }

    def create_loan_journal_entry(self):
        for rec in self:
            for contract in rec.contract_line:
                if not contract.account_move_id:
                    fee_type = contract.fee_type_id
                    journal = contract.fee_type_id.account_journal_id.id
                    date_check = self._context.get("date_check") or False
                    is_cron = self._context.get("is_cron") or False
                    if is_cron:
                        _log.info("date_check: %s", is_cron)
                        _log.info("date_today: %s", date.today())
                        date_journal = fields.Date.context_today
                    else:
                        date_journal = (
                            self._context.get("journal_date")
                            if date_check
                            else contract.order_date
                        )
                    lease_account = self.env["mofi.leasing.account"].search(
                        [
                            ("funding_type_id", "=", rec.funding_type_id.id),
                            ("channel_id", "=", rec.channel_id.id),
                            ("loan_purpose_id", "=", rec.loan_purpose_id.id),
                            ("is_restructure", "=", rec.is_restructure),
                            ("fee_type_id", "=", fee_type.id),
                            ("active", "=", True),
                        ]
                    )
                    for lease in lease_account:
                        account_move = self.env["account.move"].create(
                            {
                                "partner_id": rec.debtor_id.id,
                                "ref": rec.name,
                                "date": date_journal,
                                "journal_id": journal,
                                "auto_post": "no",
                                "state": "draft",
                                "contract_ref": rec.id,
                            }
                        )

                        def check_account_type(account):
                            if account.account_type == "asset_receivable":
                                return rec.end_date
                            elif account.account_type == "liability_payable":
                                return rec.start_date + timedelta(days=30)
                            else:
                                return False

                        account_debit = lease.debit_account_id
                        account_credit = lease.credit_account_id
                        maturity_date_debit = check_account_type(account_debit)
                        maturity_date_credit = check_account_type(account_credit)
                        account_move_line = self.env["account.move.line"].with_context(
                            check_move_validity=False
                        )
                        account_move_line.create(
                            {
                                "move_id": account_move.id,
                                "account_id": account_debit.id,
                                "partner_id": rec.debtor_id.id,
                                "name": fee_type.name,
                                "debit": contract.amount,
                                "credit": 0.0,
                                "date_maturity": maturity_date_debit,
                            }
                        )
                        account_move_line.create(
                            {
                                "move_id": account_move.id,
                                "account_id": account_credit.id,
                                "partner_id": rec.debtor_id.id,
                                "name": fee_type.name,
                                "debit": 0.0,
                                "credit": contract.amount,
                                "date_maturity": maturity_date_credit,
                            }
                        )
                        if account_move:
                            # account_move.action_post()
                            contract.account_move_id = account_move.id

    def create_payment_journal_entry(self):
        for rec in self:
            for payment in rec.payment_line:
                journal = payment.fee_type_id.account_journal_id.id
                is_je_exist = self.check_journal_entries_exist(rec.name, journal)
                # if not is_je_exist:
                if not payment.account_move_id:
                    fee_type = payment.fee_type_id
                    is_cron = self._context.get("is_cron") or False
                    date_check = self._context.get("date_check") or False
                    date_journal = (
                        self._context.get("journal_date")
                        if date_check
                        else payment.order_date
                    )
                    if is_cron and date_check:
                        date_journal = date.today()
                    elif is_cron and not date_check:
                        date_journal = payment.order_date
                    lease_account = self.env["mofi.leasing.account"].search(
                        [
                            ("funding_type_id", "=", rec.funding_type_id.id),
                            ("channel_id", "=", rec.channel_id.id),
                            ("loan_purpose_id", "=", rec.loan_purpose_id.id),
                            ("is_restructure", "=", rec.is_restructure),
                            ("fee_type_id", "=", fee_type.id),
                            ("active", "=", True),
                        ]
                    )
                    for lease in lease_account:
                        account_move = self.env["account.move"].create(
                            {
                                "partner_id": rec.debtor_id.id,
                                "ref": rec.name,
                                "date": date_journal,
                                "journal_id": journal,
                                "auto_post": "no",
                                "state": "draft",
                                "contract_ref": rec.id,
                            }
                        )

                        def check_account_type(account):
                            if account.account_type == "asset_receivable":
                                return rec.end_date
                            elif account.account_type == "liability_payable":
                                return rec.start_date + timedelta(days=30)
                            else:
                                return False

                        account_debit = lease.debit_account_id
                        account_credit = lease.credit_account_id
                        maturity_date_debit = check_account_type(account_debit)
                        maturity_date_credit = check_account_type(account_credit)
                        account_move_line = self.env["account.move.line"].with_context(
                            check_move_validity=False
                        )
                        account_move_line.create(
                            {
                                "move_id": account_move.id,
                                "account_id": account_debit.id,
                                "partner_id": rec.debtor_id.id,
                                "name": fee_type.name,
                                "debit": payment.amount,
                                "credit": 0.0,
                                "date_maturity": maturity_date_debit,
                            }
                        )
                        account_move_line.create(
                            {
                                "move_id": account_move.id,
                                "account_id": account_credit.id,
                                "partner_id": rec.debtor_id.id,
                                "name": fee_type.name,
                                "debit": 0.0,
                                "credit": payment.amount,
                                "date_maturity": maturity_date_credit,
                            }
                        )
                        if account_move:
                            # account_move.action_post()
                            payment.write({"account_move_id": account_move.id})

    def create_interest_journal_entry(self):
        for rec in self:
            move = self.env["account.move"]
            for interest in rec.interest_line:
                journal = interest.fee_type_id.account_journal_id.id
                fee_type = interest.fee_type_id
                is_cron = self._context.get("is_cron")
                date_check = self._context.get("date_check")
                date_journal = (
                    self._context.get("journal_date")
                    if date_check
                    else interest.order_date
                )
                if is_cron and date_check:
                    date_journal = date.today()
                elif is_cron and not date_check:
                    date_journal = interest.order_date
                if (
                    not interest.eom_account_move_id
                    or not interest.journal_account_move_id
                ):
                    lease_account = self.env["mofi.leasing.account"].search(
                        [
                            ("funding_type_id", "=", rec.funding_type_id.id),
                            ("channel_id", "=", rec.channel_id.id),
                            ("loan_purpose_id", "=", rec.loan_purpose_id.id),
                            ("is_restructure", "=", rec.is_restructure),
                            ("fee_type_id", "=", fee_type.id),
                            ("active", "=", True),
                        ]
                    )
                    create_date = rec.create_date.date()
                    order_date = interest.order_date or create_date
                    auto_post = "no" if order_date < create_date else "at_date"
                    for lease in lease_account:
                        account_debit = lease.debit_account_id
                        account_credit = lease.credit_account_id
                        amount_to_eom = interest.interest_to_eom or 0.0
                        amount_to_due_date = interest.interest_to_due_date or 0.0

                        def check_account_type(account):
                            if account.account_type == "asset_receivable":
                                return rec.end_date
                            elif account.account_type == "liability_payable":
                                return rec.start_date + timedelta(days=30)
                            else:
                                return False

                        maturity_date_debit = check_account_type(account_debit)
                        maturity_date_credit = check_account_type(account_credit)
                        account_move_line = self.env["account.move.line"].with_context(
                            check_move_validity=False
                        )
                        if amount_to_eom > 0.0:
                            account_move_to_eom = move.create(
                                {
                                    "partner_id": rec.debtor_id.id,
                                    "ref": rec.name,
                                    "date": date_journal,
                                    "journal_id": journal,
                                    "auto_post": auto_post,
                                    "state": "draft",
                                    "contract_ref": rec.id,
                                }
                            )
                            account_move_line.create(
                                {
                                    "move_id": account_move_to_eom.id,
                                    "account_id": account_debit.id,
                                    "partner_id": rec.debtor_id.id,
                                    "name": fee_type.name,
                                    "debit": amount_to_eom,
                                    "credit": 0.0,
                                    "date_maturity": maturity_date_debit,
                                }
                            )
                            account_move_line.create(
                                {
                                    "move_id": account_move_to_eom.id,
                                    "account_id": account_credit.id,
                                    "partner_id": rec.debtor_id.id,
                                    "name": fee_type.name,
                                    "debit": 0.0,
                                    "credit": amount_to_eom,
                                    "date_maturity": maturity_date_credit,
                                }
                            )
                            if account_move_to_eom:
                                # if interest.order_date < create_date:
                                #     account_move_to_eom.action_post()
                                interest.eom_account_move_id = account_move_to_eom.id
                        if amount_to_due_date > 0.0:
                            account_move_to_due_date = move.create(
                                {
                                    "partner_id": rec.debtor_id.id,
                                    "ref": rec.name,
                                    "date": date_journal,
                                    "journal_id": journal,
                                    "auto_post": auto_post,
                                    "state": "draft",
                                    "contract_ref": rec.id,
                                }
                            )
                            account_move_line.create(
                                {
                                    "move_id": account_move_to_due_date.id,
                                    "account_id": account_debit.id,
                                    "partner_id": rec.debtor_id.id,
                                    "name": fee_type.name,
                                    "debit": amount_to_due_date,
                                    "credit": 0.0,
                                    "date_maturity": maturity_date_debit,
                                }
                            )
                            account_move_line.create(
                                {
                                    "move_id": account_move_to_due_date.id,
                                    "account_id": account_credit.id,
                                    "partner_id": rec.debtor_id.id,
                                    "name": fee_type.name,
                                    "debit": 0.0,
                                    "credit": amount_to_due_date,
                                    "date_maturity": maturity_date_credit,
                                }
                            )
                            if account_move_to_due_date:
                                # if interest.order_date < create_date:
                                #     account_move_to_due_date.action_post()
                                interest.journal_account_move_id = (
                                    account_move_to_due_date.id
                                )

    def call_loan_entries_wizard(self):
        for rec in self:
            date_check = self.check_journal_entries_lock_date()
            # context = self._context.get('active_button')

            for line in rec.contract_line:
                lease_account = self.env["mofi.leasing.account"].search(
                    [
                        ("funding_type_id", "=", rec.funding_type_id.id),
                        ("channel_id", "=", rec.channel_id.id),
                        ("loan_purpose_id", "=", rec.loan_purpose_id.id),
                        ("is_restructure", "=", rec.is_restructure),
                        ("fee_type_id", "=", line.fee_type_id.id),
                        ("active", "=", True),
                    ]
                )

                if lease_account:
                    if not line.account_move_id:
                        if not date_check:
                            self.env.cr.execute("""SELECT generate_loan(%s)""" % (rec.id))
                            self.env.cr.commit()
                            context = {"source": "orm", "contract_number": rec.name}
                            self.with_context(context).action_reconcile_loan_entries()
                        else:
                            return {
                                "name": _("Generate Loan Entries"),
                                "type": "ir.actions.act_window",
                                "view_mode": "form",
                                "res_model": "mofi.loan.entries",
                                "target": "new",
                                "context": {"active_id": self.id},
                                "view_id": self.env.ref(
                                    "mofi_leasing.view_loan_entries_wizard"
                                ).id,
                            }

    def _action_generate_active_contract_wrapper(self):
        for rec in self.search([('status', '=', 'draft')]):
            rec.button_active()

    def _action_reconcile_all_contract(self):
        self._cr.execute("ALTER TABLE leasing_contract ADD COLUMN IF NOT EXISTS reconcile_scheduler boolean default false;")
        self._cr.execute("SELECT id FROM leasing_contract WHERE reconcile_scheduler is false ORDER by name LIMIT 1000;")
        datas = self._cr.fetchall()
        for rec in self.search([('id', 'in', datas)]):
            context = {"source": "scheduler", "contract_number": rec.name,"filename": "Schedule Action"}
            try:
                rec.with_context(context).action_reconcile_loan_entries()
                rec.with_context(context).action_reconcile_payment_entries()
                self._cr.execute("""UPDATE leasing_contract SET reconcile_scheduler = True WHERE id = %s""" % (rec.id))
                self._cr.commit()
            except UserError as e:
                _log.error("Contract %s cant reconcile" % rec.name)
        print('DONE')


class LeasingContractLine(models.Model):
    _name = "leasing.contract.line"
    _inherit = ["mail.thread", "mail.activity.mixin"]
    _description = "Leasing Contract Line"

    status = fields.Selection(
        related="contract_id.status", string="Status", copy=False, readonly=True
    )
    contract_id = fields.Many2one(
        comodel_name="leasing.contract", string="Contract", index=True, copy=False
    )
    order_fee_id = fields.Char(string="Order Fee", copy=True)
    leasing_line_id = fields.Char(string="Order ID", copy=True)
    order_date = fields.Datetime(string="Order Date", tracking=True, copy=True)
    order_type_id = fields.Many2one("mofi.order.type", string="Order Type", copy=True)
    suborder_type_id = fields.Many2one(
        "mofi.suborder.type", string="Sub Order Type", copy=True
    )
    fee_type_id = fields.Many2one(
        "mofi.fee.type", string="Fee Type", tracking=True, copy=True
    )
    amount = fields.Monetary(string="Amount", tracking=True, copy=True)
    account_move_id = fields.Many2one("account.move", string="Journal", copy=False)
    payment_channel_id = fields.Many2one(
        "mofi.payment.channel", string="Payment Channel", tracking=True, copy=True
    )
    account_journal_id = fields.Many2one(
        comodel_name="account.journal",
        string="Account No",
        copy=True,
        domain=[("type", "in", ("cash", "bank"))],
    )
    amortization = fields.Boolean(
        string="Is Amortization",
        compute="_compute_amortization_id",
        tracking=True,
        store=True,
        readonly=False,
        copy=True,
    )
    amortization_id = fields.Many2one(
        comodel_name="mofi.leasing.amortization", string="Amortization", copy=False
    )
    currency_id = fields.Many2one(
        string="Currency",
        comodel_name="res.currency",
        default=lambda self: self.env.company.currency_id.id,
        copy=True,
    )
    company_id = fields.Many2one(
        "res.company",
        string="Company",
        default=lambda self: self.env.company,
        store=True,
    )

    @api.depends("fee_type_id")
    def _compute_amortization_id(self):
        for line in self:
            line.amortization = line.fee_type_id.is_amortization


class LeasingContractPayment(models.Model):
    _name = "leasing.contract.payment"
    _inherit = ["mail.thread", "mail.activity.mixin"]
    _description = "Leasing Contract Payment"

    status = fields.Selection(
        related="contract_id.status", string="Status", copy=False, readonly=False
    )
    contract_id = fields.Many2one(comodel_name="leasing.contract", string="Contract")
    order_fee_id = fields.Char(string="Order Fee", copy=True)
    leasing_line_id = fields.Char(string="Order ID", copy=True)
    order_date = fields.Datetime(string="Paid Date", tracking=True, copy=True)
    order_type_id = fields.Many2one("mofi.order.type", string="Payment Type", copy=True)
    suborder_type_id = fields.Many2one(
        "mofi.suborder.type", string="Sub Order Type", copy=True
    )
    fee_type_id = fields.Many2one(
        "mofi.fee.type", string="Fee Type", tracking=True, copy=True
    )
    amount = fields.Monetary(string="Amount", tracking=True, copy=True)
    currency_id = fields.Many2one(
        string="Currency",
        comodel_name="res.currency",
        default=lambda self: self.env.company.currency_id.id,
        copy=True,
    )
    account_move_id = fields.Many2one("account.move", string="Journal", copy=False)
    payment_channel_id = fields.Many2one(
        "mofi.payment.channel", string="Payment Channel", tracking=True, copy=True
    )
    account_journal_id = fields.Many2one(
        "account.journal",
        string="Account No",
        copy=True,
        domain=[("type", "in", ("cash", "bank"))],
    )
    manual_payment = fields.Boolean(string="Manual Payment", tracking=True, copy=True)
    company_id = fields.Many2one(
        "res.company",
        string="Company",
        default=lambda self: self.env.company,
        store=True,
    )

    def action_edit(self):
        for journal in self:
            journal.action_unreconcile()
            journal.account_move_id.button_draft()
            journal.account_move_id.button_cancel()
            journal.account_move_id.unlink()
            # journal.write({'status': 'draft'})

    def action_unreconcile(self):
        # self.account_move_id.line_ids.remove_move_reconcile()
        for record in self:
            record.account_move_id.line_ids.with_context(
                force_delete=True
            ).remove_move_reconcile()
            # record.account_move_id.line_ids.with_context(force_delete=True).button_draft()
            # record.account_move_id.line_ids.with_context(force_delete=True).button_cancel()


class LeasingInterest(models.Model):
    _name = "leasing.contract.interest"
    _inherit = ["mail.thread", "mail.activity.mixin"]
    _description = "Leasing Interest"

    status = fields.Selection(
        related="contract_id.status", string="Status", copy=False, readonly=True
    )
    contract_id = fields.Many2one(comodel_name="leasing.contract", string="Contract")
    due_date = fields.Datetime(string="Due Date", tracking=True, copy=True)
    order_date = fields.Datetime(string="Order Date", tracking=True, copy=True)
    fee_type_id = fields.Many2one(
        "mofi.fee.type", string="Fee Type", tracking=True, copy=True
    )
    percen_accrual = fields.Float(string="% Based on Accrual", tracking=True, copy=True)
    eom_account_move_id = fields.Many2one(
        "account.move", string="Journal to EOM", copy=False
    )
    journal_account_move_id = fields.Many2one(
        "account.move", string="Journal to Due Date", copy=False
    )
    interest_to_eom = fields.Monetary(
        string="Accrual Interest To EOM", tracking=True, copy=True
    )
    interest_to_due_date = fields.Monetary(
        string="Accrual Interest To Due Date", tracking=True, copy=True
    )
    total_accrual = fields.Monetary(
        string="Total Accrual",
        compute="_compute_total_accrual",
        tracking=True,
        copy=True,
    )
    currency_id = fields.Many2one(
        string="Currency",
        comodel_name="res.currency",
        default=lambda self: self.env.company.currency_id.id,
    )

    # total_interest = fields.Monetary(string="Total Interest", tracking=True, copy=True)
    @api.depends("interest_to_eom", "interest_to_due_date")
    def _compute_total_accrual(self):
        for line in self:
            line.total_accrual = line.interest_to_eom + line.interest_to_due_date or 0.0
