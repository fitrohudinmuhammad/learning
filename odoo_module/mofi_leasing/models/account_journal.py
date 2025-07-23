from odoo import models, fields, api, _


class AccountJournal(models.Model):
    _inherit = 'account.journal'

    technical_code = fields.Char()