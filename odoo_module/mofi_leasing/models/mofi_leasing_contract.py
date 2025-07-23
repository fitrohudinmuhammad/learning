from odoo import models, fields, api
from datetime import date


import logging

_log = logging.getLogger(__name__)


class LeasingContract(models.Model):
    """
    inherit leasing contract for all function run for cron
    """
    _inherit = "leasing.contract"

    def _action_run_generate_loan_entry(self):
        leasing_contract = self.env["leasing.contract"].search(
            [("status", "=", "draft")]
        )
        for contract in leasing_contract:
            _log.info("contrat list : %s", contract.name)
            date_journal = date.today()
            try:
                if (
                    contract.contract_line
                    and not contract.contract_line.account_move_id
                ):
                    # contract.with_context(is_cron=True).create_loan_journal_entry()
                    self.env.cr.execute(
                        """SELECT generate_loan(%(id)s)""", {"id": contract.id}
                    )
                    self.env.cr.commit()
            except Exception as e:
                _log.warning(e)

    def _action_run_generate_payment_entries(self):
        leasing_contract = self.env["leasing.contract"].search(
            [("status", "=", "active")]
        )
        try:
            for contract in leasing_contract:
                _log.info("check interest for contract : %s", contract.name)
                for payment in contract.payment_line:
                    if not payment.account_move_id:
                        _log.info("generate interest for contract : %s", contract.name)
                        # contract.with_context(is_cron=True).create_payment_journal_entry()
                        self.env.cr.execute(
                            """SELECT generate_payment(%(id)s)""", {"id": contract.id}
                        )
                        self.env.cr.commit()
        except Exception as e:
            _log.warning("Some fault condition met: %s ", e)

    def _action_run_generate_interest_entries(self):
        leasing_contract = self.env["leasing.contract"].search(
            [("status", "=", "active")]
        )
        try:
            for contract in leasing_contract:
                _log.info("check interest for contract : %s", contract.name)
                for interest in contract.interest_line:
                    if (
                        not interest.journal_account_move_id
                        and not interest.eom_account_move_id
                        and contract.total_interest > 0.0
                    ):
                        _log.info(
                            "generate journal for interest tab from contract : %s",
                            contract.name,
                        )
                        # contract.with_context(is_cron=True).create_interest_journal_entry()
                        self.env.cr.execute(
                            """SELECT generate_interest(%(id)s)""", {"id": contract.id}
                        )
                        self.env.cr.commit()
                contract.action_reconcile_payment_entries()
        except Exception as e:
            _log.warning("Some fault condition met: %s ", e)

    def _action_termination_contract(self):
        leasing_contract = self.env["leasing.contract"].search(
            [("status", "=", "active")]
        )
        try:
            for contract in leasing_contract:
                _log.info("check data for contract : %s", contract.name)
                if contract.status == "active":
                    _log.info("terminate contract for contract : %s", contract.name)
                    contract.with_context(is_cron=True)._action_termination()
        except Exception as e:
            _log.warning("Some fault condition met: %s " % e)
