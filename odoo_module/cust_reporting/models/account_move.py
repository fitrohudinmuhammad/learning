from odoo import models, fields, api, _
from odoo.http import content_disposition, request

from datetime import datetime


class AccountMove(models.Model):
    _inherit = "account.move"

    is_txt_created = fields.Boolean(string="Txt Created")

    def _get_report_invoices_filename(self):
        self.ensure_one()
        filename = f'{self.name}'
        filename += f'_{datetime.today().strftime("%Y%m%d%H%M")}'
        return filename

    def _get_report_invoices_template(self):
        data = ''
        for rec in self.sorted(lambda r: r.name):
            for line in rec.invoice_line_ids:
                data += f'{rec.id}    {rec.name}    {rec.invoice_date.strftime("%Y%m%d%H%M")}    {line.product_id.default_code}    {line.product_id.name}    {line.quantity}    '
                data += '${:,.2f}    '.format(line.price_unit)
                data += '${:,.2f}\n'.format(line.quantity * line.price_unit)

        for rec in self:
            rec.write({
                'is_txt_created': True
            })
        return data

    def action_download_file(self):
        return {
            'type': 'ir.actions.act_url',
            'url': '/cust_reporting/download_file/%s' % (self.id),
            'target': 'new',
        }
