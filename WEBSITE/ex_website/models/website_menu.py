from odoo import api, fields, models


class Menu(models.Model):
    _inherit = "website.menu"
    _description = "Website Menu"