from odoo import models, fields, api, _


class AccountMove(models.Model):
  _inherit = 'account.move'
  _description = 'Account Move'

  def action_generate_faktur(self):
    return self.env.ref('iv_report_faktur.faktur_report_xlsx').report_action(self)
