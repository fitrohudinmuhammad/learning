# -*- coding: utf-8 -*-
# Part of Odoo. See LICENSE file for full copyright and licensing details.

from collections import defaultdict

from odoo import api, fields, models
from odoo.tools import float_round


class InvoiceReportStructure(models.AbstractModel):
    _name = 'report.cust_reporting.invoice_report_structure'

    def get_lines(self, productions):
        ProductProduct = self.env['product.product']
        StockMove = self.env['stock.move']
        res = []
        currency_table = self.env['res.currency']._get_query_currency_table(self.env.companies.ids, fields.Date.today())
        for move in productions:
            for product in move.invoice_line_ids.mapped('product_id'):
                mos = move.invoice_line_ids.filtered(lambda m: m.product_id == product)
                total_cost_by_mo = defaultdict(float)
                component_cost_by_mo = defaultdict(float)

                operations = []
                raw_material_moves = {}
                total_cost = 0.0
                query_str = """SELECT
                                    aml.product_id,
                                    am.id,
                                    abs(SUM(aml.quantity)),
                                    abs(SUM(aml.price_unit)),
                                    currency_table.rate
                                FROM account_move AS am
                            JOIN account_move_line AS aml ON aml.move_id = am.id
                            LEFT JOIN {currency_table} ON currency_table.company_id = am.company_id
                                WHERE am.id in %s AND am.state != 'cancel' AND aml.quantity != 0
                            GROUP BY aml.product_id, am.id, currency_table.rate""".format(currency_table=currency_table,)
                self.env.cr.execute(query_str, (tuple(mos.ids), ))
                for product_id, am_id, qty, cost, currency_rate in self.env.cr.fetchall():
                    cost *= currency_rate
                    if product_id in raw_material_moves:
                        product_moves = raw_material_moves[product_id]
                        product_moves['cost'] += cost
                        product_moves['qty'] += qty
                    else:
                        raw_material_moves[product_id] = {
                        'qty': qty,
                        'cost': cost,
                        'product_id': ProductProduct.browse(product_id),
                    }
                    total_cost_by_mo[am_id] += cost
                    component_cost_by_mo[am_id] += cost
                    total_cost += cost
                raw_material_moves = list(raw_material_moves.values())

                uom = product.uom_id
                mo_qty = 0
                for m in mos:
                    mo_qty += sum(m.filtered(lambda mo: mo.move_id.state == 'posted' and mo.product_id == product).mapped('quantity'))

                res.append({
                    'product': product,
                    'qty': mo_qty,
                    'uom': uom,
                    'operations': operations,
                    'currency': self.env.company.currency_id,
                    'total_cost': total_cost,
                    'raw_material_moves': raw_material_moves,
                    'mocount': len(mos),
                })
        print(res)
        return res

    @api.model
    def _get_report_values(self, docids, data=None):
        productions = self.env['account.move']\
            .browse(docids)\
            .filtered(lambda p: p.state != 'cancel')
        res = None
        if all(production.state == 'posted' for production in productions):
            res = self.get_lines(productions)
        return {'lines': res}