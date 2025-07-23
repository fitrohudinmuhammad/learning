from odoo import fields, models

class MofiAccountBankNo(models.Model):
    _name = 'mofi.bank.account'
    _description = 'Bank accont no'

    name = fields.Char(string="Account No", required=True)
    active = fields.Boolean(string="Active")
