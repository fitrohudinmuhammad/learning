import hashlib
import string
import secrets
from odoo import models, fields, api, _


class ApiHandler(models.Model):
    _name = "pci.api.handler"
    _inherit = ["mail.thread"]
    _description = "Call API endpoints"

    def _default_encrypt_salt(self):
        alphabet = string.ascii_letters + string.digits
        return ''.join(secrets.choice(alphabet) for i in range(16))

    name = fields.Char(required=True, tracking=True)
    user_id = fields.Many2one('res.users', string="Related User", tracking=True)
    root_user = fields.Boolean("Root User", tracking=True)
    active = fields.Boolean("Active", tracking=True, default=True)
    manual_key = fields.Boolean("Manual API Key?", default=False)
    incoming_api_key = fields.Char(compute="_compute_credentials", store=True, tracking=True, readonly=False)
    expire_date = fields.Datetime(string="Expiration date")
    encrypt_salt = fields.Char(string="Encript Salt", default=_default_encrypt_salt)
    access_all_endpoints = fields.Boolean(string='Access All Endpoint?', default=False)
    endpoints = fields.Text()

    @api.depends('user_id', 'encrypt_salt')
    def _compute_credentials(self):
        config_env = self.env['ir.config_parameter'].sudo()
        database_uuid = config_env.get_param('database.uuid')
        for rec in self:
            incoming_api_key = rec.incoming_api_key
            if not rec.manual_key:
                api_key = database_uuid + str(rec.user_id.id) + rec.encrypt_salt
                incoming_api_key = hashlib.sha256(api_key.encode()).hexdigest()

            rec.incoming_api_key = incoming_api_key

    def button_generate_new_key(self):
        self.ensure_one()
        alphabet = string.ascii_letters + string.digits
        self.write({'encrypt_salt': ''.join(secrets.choice(alphabet) for i in range(16))})

    # TODO - add the possibility to match some url like /aaa/* or /aaa/**
    # NOTE - What should be the match on the query string ? should it be trimed ?
    def is_authorized_endpoint(self, endpoint):
        self.ensure_one()
        if self.access_all_endpoints:
            return True

        configured_endpoints = self.endpoints and self.endpoints.split(',') or []

        return endpoint in configured_endpoints
