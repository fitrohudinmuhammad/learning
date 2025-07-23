from odoo import fields, models, _
from odoo.exceptions import UserError

class MofiChannel(models.Model):
    _name = 'mofi.channel'
    _description = 'Chanel'

    name =  fields.Char(string='Name',required=True, copy=True)
    code =  fields.Char(string='Code',required=True, copy=True)
    active = fields.Boolean(default=True)

    def unlink(self):
        for rec in self:
            loan = self.env['leasing.contract'].search([('channel_id', '=', rec.id)])
            if loan:
                raise UserError(_("You cannot delete a Channel information that is already used in Contract."))
        return super(MofiChannel, self).unlink()
