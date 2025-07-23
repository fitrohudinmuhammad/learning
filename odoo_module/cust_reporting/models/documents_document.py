import base64
import json
import logging
from pathlib import Path

from odoo import _, api, fields, models

_logger = logging.getLogger(__name__)


class Document(models.Model):
    _inherit = 'documents.document'

    @api.model
    def _action_open_invoice_report(self, params):
        spreadsheet = (
            self.env["documents.document"]
            .sudo()
            .search([('name', '=', 'Invoice Report')])
        )

        with open(Path(str(Path(__file__).resolve().parent.parent) + '/data/files/invoice_report.json'), 'r') as file:
            datas = json.load(file)

        context = []
        if params['date_from']:
            context.append(('date', '>=', params['date_from']))
        if params['date_to']:
            context.append(('date', '<=', params['date_to']))
        if params['salesperson_id']:
            context.append(('move_id.invoice_user_id', '=', params['salesperson_id'].id))

        _logger.info(self.env['account.move.line'].search(context))

        cells = {}
        no = 2
        rows = 0
        for rec in self.env['account.move.line'].search(context):
            rows += 1
            invline_data = rec

            cell = {
                'A' + str(no): {"content": str(rows), "style": 2},
                'B' + str(no): {"content": str(invline_data.id), "style": 2},
                'C' + str(no): {"content": str(invline_data.product_id.product_tmpl_id.default_code), "style": 2},
                'D' + str(no): {"content": str(invline_data.product_id.product_tmpl_id.name), "style": 2},
                'E' + str(no): {"content": str(invline_data.move_id.invoice_user_id.name), "style": 2},
                'F' + str(no): {"content": str(invline_data.move_id.partner_id.type), "style": 2},
                'G' + str(no): {"content": str(invline_data.move_id.partner_id.name), "style": 2},
                'H' + str(no): {"content": str(invline_data.partner_id.ref), "style": 2},
                'I' + str(no): {"content": str(invline_data.move_id.name), "style": 2},
                'J' + str(no): {"content": str(invline_data.move_id.invoice_date), "style": 2},
                'K' + str(no): {"content": str(invline_data.account_id.name), "style": 2},
                'L' + str(no): {"content": str(invline_data.quantity), "style": 2},
                'M' + str(no): {"content": str('${:,.2f}'.format(invline_data.price_unit)), "style": 2},
                'N' + str(no): {"content": str('${:,.2f}'.format(invline_data.price_subtotal)), "style": 2},
                'O' + str(no): {"content": str('${:,.2f}'.format(invline_data.product_id.product_tmpl_id.standard_price)), "style": 2},
                'P' + str(no): {"content": str('${:,.2f}'.format(invline_data.product_id.standard_price * invline_data.quantity)), "style": 2},
                'Q' + str(no): {"content": str('${:,.2f}'.format(invline_data.discount)), "style": 2},
                'R' + str(no): {"content": str(invline_data.product_id.product_tmpl_id.categ_id.complete_name if invline_data.product_id.product_tmpl_id.categ_id.id else ""), "style": 2},
                'S' + str(no): {"content": str(invline_data.product_id.product_tmpl_id.categ_id.name if invline_data.product_id.product_tmpl_id.categ_id.id else ""), "style": 2},
            }
            no += 1
            cells.update(cell)

        datas.get('sheets')[0].update({
            'rowNumber': rows,
        })
        datas.get('sheets')[0].get('cells').update(cells)

        if not spreadsheet:
            folder = self.env["documents.folder"].search([('name', '=', 'Cust Report')])
            if not folder:
                folder = self.env["documents.folder"].create({"name": "Cust Report"})
            spreadsheet = (
                self.env["documents.document"]
                .create({
                    'name': 'Invoice Report',
                    'folder_id': folder.id,
                    'spreadsheet_data': json.dumps(datas),
                    'datas': base64.encodebytes(json.dumps(datas).encode()),
                    'handler': 'spreadsheet',
                    "mimetype": "application/o-spreadsheet",
                    "active": True,
                })
            )
            attachment = self.env["ir.attachment"].create({
                "name": "Invoice Report",
                "datas": base64.encodebytes(json.dumps(datas).encode()),
                "res_model": "documents.document",
                "res_id": spreadsheet.id,
            })

        spreadsheet.write({
            'spreadsheet_data': json.dumps(datas),
            'datas': base64.encodebytes(json.dumps(datas).encode()),
        })
        self.env["ir.attachment"].search([('res_id', '=', spreadsheet.id)]).write({
            'datas': base64.encodebytes(json.dumps(datas).encode()),
        })
        return {
            "type": "ir.actions.client",
            "tag": "action_open_spreadsheet",
            "params": {
                "spreadsheet_id": spreadsheet.id,
                "spreadsheet_data": datas,
            },
        }
