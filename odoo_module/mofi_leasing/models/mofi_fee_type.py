from odoo import models, fields, _
from odoo.exceptions import UserError

class MofiFeeType(models.Model):
    _name = 'mofi.fee.type'
    _description = 'Fee Type'

    name = fields.Char(string='Name', copy=True)
    code = fields.Char(string='Code', required=True, copy=True)
    active = fields.Boolean(default=True)
    account_journal_id = fields.Many2one('account.journal', string="Journal", copy=True)
    is_amortization = fields.Boolean(string="Amortization", copy=True)
    amortization_account_journal_id = fields.Many2one(
        'account.journal',
        string="Amortization Journal",
        copy=True)
    is_termination = fields.Boolean(string="Termination", copy=True)

    def unlink(self):
        loan = self.env['leasing.contract.line'].search([('fee_type_id', '=', self.id)])
        payment = self.env['leasing.contract.payment'].search([('fee_type_id', '=', self.id)])
        interest = self.env['leasing.contract.interest'].search([('fee_type_id', '=', self.id)])
        for line in self:
            # if any(line.id in
            if loan or payment or interest:
                raise UserError(_("You cannot delete a leasing account that is already used in Contract."))
        return super(MofiFeeType, self).unlink()
