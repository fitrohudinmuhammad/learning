from odoo import _, api, fields, models


class TableA(models.Model):
    _name = "table.a"
    _description = "Table A"

    name = fields.Char()
    description = fields.Char()
    notes = fields.Text()
    table_report_ids = fields.One2many('table.report', 'tablea_id')