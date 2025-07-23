from itertools import groupby
from datetime import date
import base64
import io
import logging

from odoo import models, _
from odoo.tools.misc import DEFAULT_SERVER_DATE_FORMAT

_logger = logging.getLogger(__name__)

NUM_FORMAT = '###,###.00'


class InvoiceReportXlsx(models.AbstractModel):
    _name = 'report.cust_reporting.invoice_report_xlsx'
    _inherit = 'report.report_xlsx.abstract'

    def generate_xlsx_report(self, workbook, data, datas):
        Invoices = self.env['account.move']

        # prepare format
        table_header = workbook.add_format({
            'bold': 1,
            'border': 1,
            'align': 'center',
            'valign': 'vcenter',
        })
        table_header.set_text_wrap()
        table_header.set_font_size(10)
        table_header.set_font_name('Times New Roman')

        table_body = workbook.add_format({
            'bold': 0,
            'border': 1,
            'align': 'center',
            'valign': 'vcenter',
        })
        table_body.set_text_wrap()
        table_body.set_font_name('Times New Roman')
        table_body.set_num_format(NUM_FORMAT)

        sub_total = workbook.add_format({
            'bold': 0,
            'border': 1,
            'align': 'center',
            'valign': 'vcenter',
            'fg_color': '#ffff00'
        })
        sub_total.set_text_wrap()
        sub_total.set_font_name('Times New Roman')
        sub_total.set_num_format(NUM_FORMAT)

        price_format = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter'
        })
        price_format.set_text_wrap()
        price_format.set_font_name('Times New Roman')
        price_format.set_num_format(NUM_FORMAT)

        char_total_format = workbook.add_format({
            'bold': 1,
            'border': 1,
            'align': 'right',
            'valign': 'vcenter',
        })
        char_total_format.set_text_wrap()
        char_total_format.set_font_size(10)
        char_total_format.set_font_color('red')
        char_total_format.set_font_name('Times New Roman')

        num_total_format = workbook.add_format({
            'bold': 1,
            'border': 1,
            'align': 'right',
            'valign': 'vcenter',
        })
        num_total_format.set_text_wrap()
        num_total_format.set_font_size(10)
        num_total_format.set_font_color('red')
        num_total_format.set_font_name('Times New Roman')
        num_total_format.set_num_format(NUM_FORMAT)

        row_number = workbook.add_format({
            'bold': 0,
            'border': 1,
            'align': 'center',
            'valign': 'vcenter'
        })
        row_number.set_text_wrap()
        row_number.set_font_name('Times New Roman')

        datetime_note = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter'
        })
        datetime_note.set_text_wrap()
        datetime_note.set_italic()
        datetime_note.set_font_size(10)
        datetime_note.set_font_name('Times New Roman')

        title_center = workbook.add_format({
            'bold': 1,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter',
        })
        title_center.set_text_wrap()
        title_center.set_font_size(16)
        title_center.set_font_name('Times New Roman')

        title_normal_center = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter',
        })
        title_normal_center.set_text_wrap()
        title_normal_center.set_font_size(10)
        title_normal_center.set_font_name('Times New Roman')

        subtotal_format = workbook.add_format({
            'bold': 1,
            'border': 1,
            'align': 'center',
            'valign': 'vcenter',
        })
        subtotal_format.set_text_wrap()
        subtotal_format.set_font_size(10)
        subtotal_format.set_font_name('Times New Roman')

        total_format = workbook.add_format({
            'bold': 1,
            'border': 1,
            'align': 'center',
            'valign': 'vcenter',
            'fg_color': '#8db4e2'
        })
        total_format.set_text_wrap()
        total_format.set_font_size(10)
        total_format.set_num_format(NUM_FORMAT)
        total_format.set_font_name('Times New Roman')

        title_bold_italic = workbook.add_format({
            'bold': 1,
            'border': 0,
            'align': 'left',
            'valign': 'vcenter',
        })
        title_bold_italic.set_text_wrap()
        title_bold_italic.set_italic()
        title_bold_italic.set_font_size(10)
        title_bold_italic.set_font_name('Times New Roman')

        char_center_normal = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter',
        })
        char_center_normal.set_text_wrap()
        char_center_normal.set_font_size(10)
        char_center_normal.set_font_name('Times New Roman')

        title_bold = workbook.add_format({
            'bold': 1,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter',
        })
        title_bold.set_text_wrap()
        title_bold.set_font_size(10)
        title_bold.set_font_name('Times New Roman')

        title_center_bold = workbook.add_format({
            'bold': 1,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter',
        })
        title_center_bold.set_text_wrap()
        title_center_bold.set_font_size(10)
        title_center_bold.set_font_name('Times New Roman')

        title_center_italic = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter',
        })
        title_center_italic.set_text_wrap()
        title_center_italic.set_italic()
        title_center_italic.set_font_size(10)
        title_center_italic.set_font_name('Times New Roman')

        def _header_sheet(sheet, heads):
            sheet.set_row(0, 40) # invoice id
            sheet.set_row(1, 20) # invoice name
            sheet.set_row(2, 40) # customer
            sheet.set_row(3, 20) # invoice date
            sheet.set_row(4, 20) # invoice due date
            sheet.set_row(5, 20) # product name
            sheet.set_row(6, 20) # default code
            sheet.set_row(7, 40) # qty
            sheet.set_row(8, 40) # price unit
            sheet.set_row(9, 40) # discount
            sheet.set_row(10, 40) # tax
            sheet.set_row(11, 40) # subtotal
            i = 0

            for head in heads:
                sheet.set_column(i, i, head['width'])
                sheet.set_row(5, 40)
                sheet.write(2, i, head['name'], table_header)
                i += 1

        def _prepare_heads():
            header = [
                {
                    'name': _('Invoice ID'),
                    'key': 'id',
                    'width': 5,
                    'format': row_number
                },
                {
                    'name': _('Invoice Name'),
                    'key': 'name',
                    'width': 15,
                    'format': table_body
                },
                {
                    'name': _('Customer'),
                    'key': 'partner_id',
                    'width': 20,
                    'format': table_body
                },
                {
                    'name': _('Invoice Date'),
                    'key': 'date',
                    'width': 15,
                    'format': table_body
                },
                {
                    'name': _('Invoice Due Date'),
                    'key': 'date',
                    'width': 15,
                    'format': table_body
                },
                {
                    'name': _('Product Name'),
                    'key': 'date',
                    'width': 15,
                    'format': table_body
                },
                {
                    'name': _('Default Code'),
                    'key': 'date',
                    'width': 15,
                    'format': table_body
                },
                {
                    'name': _('Qty'),
                    'key': 'date',
                    'width': 15,
                    'format': table_body
                },
                {
                    'name': _('Price Unit'),
                    'key': 'date',
                    'width': 15,
                    'format': price_format
                },
                {
                    'name': _('Discount'),
                    'key': 'date',
                    'width': 15,
                    'format': price_format
                },
                {
                    'name': _('Tax'),
                    'key': 'date',
                    'width': 15,
                    'format': price_format
                },
                {
                    'name': _('Total'),
                    'key': 'total_amount',
                    'width': 10,
                    'format': total_format
                },
            ]
            return header

        company = self.env.user.company_id

        sheet = workbook.add_worksheet(_('Invoice Done'))

        heads = _prepare_heads()

        # sheet.write('A2', 'Từ Ngày: ', header)
        # sheet.write('B2', datas.period_from.strftime(
        #     DEFAULT_SERVER_DATETIME_FORMAT), data_bold_format)
        # sheet.write('C2', 'Đến Ngày: ', header)
        # sheet.write('D2', datas.period_to.strftime(
        #     DEFAULT_SERVER_DATETIME_FORMAT), data_bold_format)
        _header_sheet(sheet, heads)
        row = 3
