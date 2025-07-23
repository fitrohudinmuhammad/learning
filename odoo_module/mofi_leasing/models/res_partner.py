from odoo import models, fields

class ResPartner(models.Model):
    _inherit = 'res.partner'

    leasing_count = fields.Integer(string="Leasing Count", compute="_compute_leasing")
    debtor_id = fields.Char(string='Debtor ID')
    company_id = fields.Many2one(
        'res.company',
        string="Company",
        index=True,
        default=lambda self: self.env.company,
        store=True,)

    def action_view_leasing(self):
        return {
            "type": "ir.actions.act_window",
            "name": "Leasing",
            "res_model": "leasing.contract",
            "view_mode": "tree,form",
            "domain": [("debtor_id.id", "=", self.id)],
        }

    def _compute_leasing(self):
        # debtor = self.debtor_id
        leasing_count = self.env['leasing.contract'].search_count([("debtor_id.id", "=", self.id)])
        self.leasing_count = leasing_count
