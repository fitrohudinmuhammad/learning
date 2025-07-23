from odoo import fields, models, _
from odoo.exceptions import UserError

class MofiLoanPurpose(models.Model):
    _name = "mofi.loan.purpose"
    _description = 'Loan Purpose'

    name = fields.Char(string='Name', copy=True)
    code = fields.Char(string='Code', required=True, copy=True)
    active = fields.Boolean(default=True)

    def unlink(self):
        for rec in self:
            loan = self.env['leasing.contract'].search([('loan_purpose_id', '=', rec.id)])
            if loan:
                raise UserError(_("You cannot delete a Loan Purpose information that is already used in Contract."))
        return super(MofiLoanPurpose, self).unlink()
