from odoo import models, fields, _
from odoo.exceptions import UserError

class MofiSubOrderType(models.Model):
    _name = "mofi.suborder.type"
    _description = "Sub Order Type"

    name = fields.Char(string='Name',required=True, copy=True)
    code = fields.Char(string='Code', required=True, copy=True)
    active = fields.Boolean(default=True)

    def unlink(self):
        for line in self:
            loan = self.env['leasing.contract.line'].search([('suborder_type_id', '=', line.id)])
            payment = self.env['leasing.contract.payment'].search([('suborder_type_id', '=', line.id)])
            # interest = self.env['leasing.contract.interest'].search([('suborder_type_id', '=', line.id)])
            # if any(line.id in
            if loan or payment:
                raise UserError(_("You cannot delete an order type that is already used in Contract."))
        return super(MofiSubOrderType, self).unlink()
