from odoo import _, api, fields, models


class TableB(models.Model):
    _name = "table.b"
    _description = "Table B"

    start_date = fields.Datetime(string='Start Date')
    end_date = fields.Datetime(string='End Date')
    duration = fields.Float(string='Duration', compute='_compute_duration', store=True)
    tablea_id = fields.Many2one('table.a', store='True')

    @api.model
    def _convert_datetime_to_float(self, start_time, end_time):
        duration_second = (end_time - start_time).total_seconds()
        duration_hours = duration_second // 3600
        duration_minutes = round(duration_second / 60) % 60
        duration = duration_hours + duration_minutes / 60
        return duration

    @api.depends('start_date', 'end_date')
    def _compute_duration(self):
        for record in self:
            if record.start_date and record.end_date:
                record.duration = record._convert_datetime_to_float(record.start_date, record.end_date)
            else:
                record.duration = 0