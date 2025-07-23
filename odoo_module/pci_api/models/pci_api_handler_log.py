import logging
from datetime import datetime, timedelta
from odoo import models, fields, api, _

_logger = logging.getLogger(__name__)


class ApiHandlerLogs(models.Model):
    _name = "pci.api.handler.log"
    _inherit = ["mail.thread", "mail.activity.mixin"]
    _description = "API Handle Logs"
    _rec_name = "api_endpoint"
    _order = 'create_date DESC'

    # handle_id = fields.Many2one('pci.api.handler', string='API Handle')
    api_endpoint = fields.Char('API Endpoint', required=True)
    request_received = fields.Text('Request Received')
    state = fields.Selection([
        ('success', 'Success'),
        ('fail', 'Fail')
    ], string='Status', default='success')
    message = fields.Text('Message')

    @api.model
    def autovacuum(self, days=10, batch=1000):
        _logger.info("Launching API log cleaning")
        sudo = self.sudo()
        record_to_delete = sudo.get_record_to_delete(days=days, limit=batch)
        while record_to_delete:
            record_to_delete.unlink()
            record_to_delete = None
            sudo.flush()
            record_to_delete = sudo.get_record_to_delete(days=days, limit=batch)

        _logger.info("API log cleaning done!")
        return True

    def get_record_to_delete(self, days=10, limit=1000):
        return self.search([('create_date', '<', datetime.now() - timedelta(days=days))], limit=limit)

    @api.model
    def create(self, vals):
        self._message_post_on_error()
        return super().create(vals)

    def _message_post_on_error(self):
        # subscribe the users now to avoid to subscribe them
        # at every job creation
        domain = self._subscribe_users_domain()
        users = self.env["res.users"].search(domain)
        for record in self:
            record.message_subscribe(partner_ids=users.mapped("partner_id").ids)
            msg = record._message_error_request2API()
            if msg:
                record.message_post(body=msg, subtype_xmlid="pci_api.mt_request_failed")

    def _subscribe_users_domain(self):
        """Subscribe all users having the 'GRAB API UMP Manager' group"""
        group = self.env.ref("grab_api_ump.group_grab_api_ump_manager")
        if not group:
            return None
        domain = [("groups_id", "=", group.id)]
        return domain

    def _message_error_request2API(self):
        self.ensure_one()
        return _(
            "Error when sending a request to Grab API."
            "Please see more details in the Message Response."
        )
