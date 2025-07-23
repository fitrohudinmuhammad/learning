from odoo import models, fields, _
from odoo.exceptions import UserError

class MofiLeasingAccount(models.Model):
    _name = 'mofi.leasing.account'
    _description = 'Mofi Leasing Account'

    name = fields.Char(string='Name')
    funding_type_id = fields.Many2one('mofi.funding.type', string="Funding Type" )
    channel_id = fields.Many2one('mofi.channel', string="Channel" )
    loan_purpose_id = fields.Many2one('mofi.loan.purpose', string="Loan Purpose" )
    is_restructure = fields.Boolean(string="Is Restructure")
    fee_type_id = fields.Many2one('mofi.fee.type', string="Fee Type")
    account_journal_id = fields.Many2one(
        'account.journal',
        string="Journal",
        related="fee_type_id.account_journal_id")
    debit_account_id = fields.Many2one('account.account', string="Debit Account")
    credit_account_id = fields.Many2one('account.account', string="Credit Account")
    amortization = fields.Boolean(
        string="Amortization",
        related="fee_type_id.is_amortization")
    journal_amortization_id = fields.Many2one(
        'account.journal',
        string="Journal Amortization",
        related="fee_type_id.amortization_account_journal_id")
    debit_account_amortization_id = fields.Many2one('account.account', string="Debit Account Amortization")
    credit_account_amortization_id = fields.Many2one('account.account', string="Credit Account Amortization")
    active = fields.Boolean(string="Active", default=True)

    def unlink(self):
        loan = self.env['leasing.contract.line'].search([('fee_type_id', '=', self.fee_type_id.id)])
        payment = self.env['leasing.contract.payment'].search([('fee_type_id', '=', self.fee_type_id.id)])
        interest = self.env['leasing.contract.interest'].search([('fee_type_id', '=', self.fee_type_id.id)])
        for line in self:
            # if any(line.id in
            if loan or payment or interest:
                raise UserError(_("You cannot delete a leasing account that is already used in Contract."))
        return super(MofiLeasingAccount, self).unlink()
