from odoo import models, fields, _
from odoo.exceptions import UserError


class MofiPaymentChannel(models.Model):
    _name = 'mofi.payment.channel'
    _description = 'Payment Channel'

    name = fields.Char(string='Name', copy=True)
    code = fields.Char(string='Code', required=True, copy=True)
    active = fields.Boolean(default=True)

    def unlink(self):
        for line in self:
            # loan = self.env['leasing.contract.line'].search([('suborder_type_id', '=', line.id)])
            # payment = self.env['leasing.contract.payment'].search([('suborder_type_id', '=', line.id)])
            interest = self.env['leasing.contract.line'].search([('payment_channel_id', '=', line.id)])
            # if any(line.id in
            if interest:
                raise UserError(_("You cannot delete a payment type that is already used in Contract."))
        return super(MofiPaymentChannel, self).unlink()
