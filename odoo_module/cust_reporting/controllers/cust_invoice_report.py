from odoo import http
from odoo.http import request, content_disposition

class CustInvoiceReportController(http.Controller):

    @http.route('/cust_reporting/download_file/<int:invoice_id>', type='http', auth='user')
    def download_file(self, invoice_id, **kwargs):
        # Generate the content of the file
        file_content = ""
        file_name = "%s.docx" % (request.env['account.move'].browse(invoice_id).name)
        for move in request.env['account.move'].browse(invoice_id):
            for line in move.invoice_line_ids:
                file_content += f'{move.id}    {move.name}    {move.invoice_date.strftime("%Y%m%d%H%M")}    {line.product_id.default_code}    {line.product_id.name}    {line.quantity}    '
                file_content += '${:,.2f}'.format(line.price_unit)
                file_content += '    '
                file_content += '${:,.2f}'.format(line.quantity * line.price_unit)
                file_content += '\n'

        # Create a response object with the file content
        response = request.make_response(
            file_content,
            headers=[
                ('Content-Type', 'text/plain'),
                ('Content-Disposition', content_disposition(file_name))
            ]
        )

        return response
