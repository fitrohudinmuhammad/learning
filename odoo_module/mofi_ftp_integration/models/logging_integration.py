from odoo import models, fields, api, _


class LoggingIntegration(models.Model):
    _name = 'logging.integration'
    _description = 'Logging Integration Model'

    name = fields.Char()
    filename = fields.Char()
    receive_date = fields.Datetime()
    receive_status = fields.Boolean(default=False)
    description = fields.Text()
    src_number_of_rows = fields.Integer()
    dest_number_of_rows = fields.Integer()
    log_time = fields.Datetime(default=lambda self: fields.Datetime.now())
    error_status = fields.Boolean(default=False)
    order_fee_id = fields.Char()
    row_id = fields.Integer()
    active = fields.Boolean(default=True)
