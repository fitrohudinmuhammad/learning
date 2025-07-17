from itertools import groupby
from datetime import date, timedelta
import time, re

from odoo import models, _
from odoo.tools.misc import DEFAULT_SERVER_DATE_FORMAT

NUM_FORMAT = '###,###'


class FakturReportXlsx(models.AbstractModel):
    _name = 'report.iv_report_faktur.faktur_report'
    _inherit = 'report.report_xlsx.abstract'
    _description = 'Faktur Report'

    def generate_xlsx_report(self, workbook, data, datas):
        # prepare format
        title_bold_center = workbook.add_format({
            'bold': 1,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter',
        })
        title_bold_center.set_font_size(11)
        title_bold_center.set_font_name('Calibri')

        title_bold_left = workbook.add_format({
            'bold': 1,
            'border': 0,
            'align': 'left',
            'valign': 'vcenter',
        })
        title_bold_left.set_font_size(11)
        title_bold_left.set_font_name('Calibri')

        title_normal_center = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter',
        })
        title_normal_center.set_font_size(11)
        title_normal_center.set_font_name('Calibri')
        
        title_normal_left = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'left',
            'valign': 'vcenter',
            'num_format': '@',
        })
        title_normal_left.set_font_size(11)
        title_normal_left.set_font_name('Calibri')

        row_number = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter'
        })
        row_number.set_font_size(11)
        row_number.set_font_name('Calibri')

        text_normal_left = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'left',
            'valign': 'vcenter',
            'num_format': '@',
        })
        text_normal_left.set_font_size(11)
        text_normal_left.set_font_name('Calibri')

        text_normal_right = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'right',
            'valign': 'vcenter',
            'num_format': '@',
        })
        text_normal_right.set_font_size(11)
        text_normal_right.set_font_name('Calibri')
        

        tanggal_normal_right = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'right',
            'valign': 'vcenter',
            'num_format': 'dd/mm/yyyy',
        })
        tanggal_normal_right.set_font_size(11)
        tanggal_normal_right.set_font_name('Calibri')

        char_normal_center = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter',
        })
        char_normal_center.set_font_size(11)
        char_normal_center.set_font_name('Calibri')

        char_normal_left = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'left',
            'valign': 'vcenter',
        })
        char_normal_left.set_font_size(11)
        char_normal_left.set_font_name('Calibri')

        char_bold_center = workbook.add_format({
            'bold': 1,
            'border': 0,
            'align': 'center',
            'valign': 'vcenter',
        })
        char_bold_center.set_font_size(11)
        char_bold_center.set_font_name('Calibri')

        char_bold_left = workbook.add_format({
            'bold': 1,
            'border': 0,
            'align': 'left',
            'valign': 'vcenter',
        })
        char_bold_left.set_font_size(11)
        char_bold_left.set_font_name('Calibri')

        char_normal_right = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'right',
            'valign': 'vcenter',
        })
        char_normal_right.set_font_size(11)
        char_normal_right.set_font_name('Calibri')

        char_bold_right = workbook.add_format({
            'bold': 1,
            'border': 0,
            'align': 'right',
            'valign': 'vcenter',
        })
        char_bold_right.set_font_size(11)
        char_bold_right.set_font_name('Calibri')

        price_format = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'right',
            'valign': 'vcenter'
        })
        price_format.set_font_name('Calibri')
        price_format.set_font_size(11)
        price_format.set_num_format(NUM_FORMAT)

        price_bold_total = workbook.add_format({
            'bold': 1,
            'border': 0,
            'align': 'right',
            'valign': 'vcenter',
        })
        price_bold_total.set_font_size(11)
        price_bold_total.set_num_format(NUM_FORMAT)
        price_bold_total.set_font_name('Calibri')

        num_normal_right = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'right',
            'valign': 'vcenter',
            'num_format': '0.00',
        })
        num_normal_right.set_font_size(11)
        num_normal_right.set_font_name('Calibri')

        num_normal_dec_right = workbook.add_format({
            'bold': 0,
            'border': 0,
            'align': 'right',
            'valign': 'vcenter',
            'num_format': '0',
        })
        num_normal_dec_right.set_font_size(11)
        num_normal_dec_right.set_font_name('Calibri')
        ######################################################################################
        ######################################################################################

        inv_data = []
        urutan = 0
        for invoice in datas:
            urutan += 1
            inv_line = []
            for line in invoice.invoice_line_ids:
                unit_price = round(line.net_price / 1.11,2)
                inv_line.append({
                    'nama_barang': line.product_id.name,
                    'unit_price': unit_price,
                    'qty': line.quantity,
                    'diskon': 0,
                    'dpp': line.quantity * unit_price,
                    'dpp_lain': (line.quantity * unit_price) * 11/12,
                    'tarif_ppn': ((line.quantity * unit_price ) * 11/12) * 0.12,
                })
            if invoice.partner_id.vat:
                if len(re.sub(r'\D', '', invoice.partner_id.vat)) < 16:
                    npwp = '0' + invoice.partner_id.vat
                else:
                    npwp = invoice.partner_id.vat
            else:
                npwp = None

            inv_data.append({
                'baris': urutan,
                'tgl_faktur': invoice.invoice_date.strftime('%d/%m/%Y'),
                'inv_number': invoice.name,
                'npwp_cust': npwp,
                'cust_name': invoice.partner_id.name,
                'inv_line': inv_line,
            })

        sheet_1 = workbook.add_worksheet(_('Faktur'))

        sheet_1.set_column('A:A', 5)
        sheet_1.set_column('B:B', 15)
        sheet_1.set_column('C:C', 15)
        sheet_1.set_column('D:D', 15)
        sheet_1.set_column('E:E', 25)
        sheet_1.set_column('F:F', 25)
        sheet_1.set_column('G:G', 20)
        sheet_1.set_column('H:H', 20)
        sheet_1.set_column('I:I', 20)
        sheet_1.set_column('J:J', 30)
        sheet_1.set_column('K:K', 25)
        sheet_1.set_column('L:L', 27)
        sheet_1.set_column('M:M', 20)
        sheet_1.set_column('N:N', 30)
        sheet_1.set_column('O:O', 30)
        sheet_1.set_column('P:P', 25)
        sheet_1.set_column('Q:Q', 25)
        sheet_1.set_column('R:R', 22)

        sheet_1.merge_range('A1:B1', 'NPWP Penjual', title_bold_center)
        sheet_1.write('C1', '0403410939043000', title_normal_left)

        sheet_1.write('A3', 'Baris', title_bold_left)
        sheet_1.write('B3', 'Tanggal Faktur', title_bold_left)
        sheet_1.write('C3', 'Jenis Faktur', title_bold_left)
        sheet_1.write('D3', 'Kode Transaksi', title_bold_left)
        sheet_1.write('E3', 'Keterangan Tambahan', title_bold_left)
        sheet_1.write('F3', 'Dokumen Pendukung', title_bold_left)
        sheet_1.write('G3', 'Period Dok Pendukung', title_bold_left)
        sheet_1.write('H3', 'Referensi', title_bold_left)
        sheet_1.write('I3', 'Cap Fasilitas', title_bold_left)
        sheet_1.write('J3', 'ID TKU Penjual', title_bold_left)
        sheet_1.write('K3', 'NPWP/NIK Pembeli', title_bold_left)
        sheet_1.write('L3', 'Jenis ID Pembeli', title_bold_left)
        sheet_1.write('M3', 'Negara Pembeli', title_bold_left)
        sheet_1.write('N3', 'Nomor Dokumen Pembeli', title_bold_left)
        sheet_1.write('O3', 'Nama Pembeli', title_bold_left)
        sheet_1.write('P3', 'Alamat Pembeli', title_bold_left)
        sheet_1.write('Q3', 'Email Pembeli', title_bold_left)
        sheet_1.write('R3', 'ID TKU Pembeli', title_bold_left)

        row = 4

        for data in inv_data:
            sheet_1.write('A' + str(row), str(data['baris']), text_normal_left)
            sheet_1.write('B' + str(row), data['tgl_faktur'], tanggal_normal_right)
            sheet_1.write('C' + str(row), 'Normal', char_normal_left)
            sheet_1.write('D' + str(row), '04', text_normal_left)
            sheet_1.write('E' + str(row), '', text_normal_left)
            sheet_1.write('F' + str(row), '', text_normal_left)
            sheet_1.write('G' + str(row), '', text_normal_left)
            sheet_1.write('H' + str(row), data['inv_number'], text_normal_left)
            sheet_1.write('I' + str(row), '', text_normal_left)
            sheet_1.write('J' + str(row), '0403410939043000000000', text_normal_left)
            sheet_1.write('K' + str(row), data['npwp_cust'] if data['npwp_cust'] else '0000000000000000', text_normal_left)
            sheet_1.write('L' + str(row), 'TIN', text_normal_left)
            sheet_1.write('M' + str(row), 'IDN', text_normal_left)
            sheet_1.write('N' + str(row), '-', text_normal_left)
            sheet_1.write('O' + str(row), data['cust_name'], text_normal_left)
            sheet_1.write('P' + str(row), 'Jakarta', text_normal_left)
            sheet_1.write('Q' + str(row), '', text_normal_left)
            sheet_1.write('R' + str(row), str(data['npwp_cust']) + '000000', text_normal_left)

            row +=1
        sheet_1.write('A' + str(row),'END', char_bold_left)
        ######################################################################################

        sheet_2 = workbook.add_worksheet(_('DetailFaktur'))

        sheet_2.set_column('A:A', 5)
        sheet_2.set_column('B:B', 15)
        sheet_2.set_column('C:C', 20)
        sheet_2.set_column('D:D', 50)
        sheet_2.set_column('E:E', 15)
        sheet_2.set_column('F:F', 15)
        sheet_2.set_column('G:G', 20)
        sheet_2.set_column('H:H', 15)
        sheet_2.set_column('I:I', 15)
        sheet_2.set_column('J:J', 15)
        sheet_2.set_column('K:K', 10)
        sheet_2.set_column('L:L', 15)
        sheet_2.set_column('M:M', 15)
        sheet_2.set_column('N:N', 15)

        sheet_2.write('A1', 'Baris', char_normal_left)
        sheet_2.write('B1', 'Barang/Jasa', char_normal_left)
        sheet_2.write('C1', 'Kode Barang Jasa', char_normal_left)
        sheet_2.write('D1', 'Nama Barang/Jasa', char_normal_left)
        sheet_2.write('E1', 'Nama Satuan Ukur', char_normal_left)
        sheet_2.write('F1', 'Harga Satuan', char_normal_left)
        sheet_2.write('G1', 'Jumlah Barang Jasa', char_normal_left)
        sheet_2.write('H1', 'Total Diskon', char_normal_left)
        sheet_2.write('I1', 'DPP', char_normal_left)
        sheet_2.write('J1', 'DPP Nilai Lain', char_normal_left)
        sheet_2.write('K1', 'Tarif PPN', char_normal_left)
        sheet_2.write('L1', 'PPN', char_normal_left)
        sheet_2.write('M1', 'Tarif PPnBM', char_normal_left)
        sheet_2.write('N1', 'PPnBM', char_normal_left)

        row = 2

        for data in inv_data:
            for line in data['inv_line']:
                sheet_2.write('A' + str(row), str(data['baris']), text_normal_right)
                sheet_2.write('B' + str(row), 'A', char_normal_left)
                sheet_2.write('C' + str(row), '000000', char_normal_left)
                sheet_2.write('D' + str(row), line['nama_barang'], char_normal_left)
                sheet_2.write('E' + str(row), 'UM.0018', char_normal_left)
                sheet_2.write('F' + str(row), line['unit_price'], char_normal_right)
                sheet_2.write('G' + str(row), line['qty'], num_normal_dec_right)
                sheet_2.write('H' + str(row), -1*line['diskon'] if line['diskon'] < 0 else line['diskon'], num_normal_right)
                # sheet_2.write('I' + str(row), line['dpp'], num_normal_right)
                # sheet_2.write('J' + str(row), line['dpp_lain'], num_normal_right)

                sheet_2.write('I' + str(row), '=G'+str(row)+'*F'+str(row)+'-H'+str(row), num_normal_right)
                sheet_2.write('J' + str(row), '=11/12*I'+str(row), num_normal_right)
                
                sheet_2.write('K' + str(row), 12, char_normal_right)
                # sheet_2.write('L' + str(row), line['tarif_ppn'], num_normal_right)

                sheet_2.write('L' + str(row), '=J'+str(row)+'*K'+str(row)+'/100', num_normal_right)
                sheet_2.write('M' + str(row), 0, char_normal_right)
                sheet_2.write('N' + str(row), '=M'+str(row)+'*J'+str(row)+'/100', num_normal_right)

                row +=1
        sheet_2.write('A' + str(row),'END', char_normal_left)
        return {'type': 'ir.actions.act_window_close'}
