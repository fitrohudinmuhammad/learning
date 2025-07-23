from odoo import models, fields, _
import requests
import json
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


class ProductTemplate(models.Model):
    _inherit = 'product.template'
    _name = 'product.template'

    def action_sent_data_by_api(self):
        datalist = []
        if len(self) > 1:
            for lin in self:
                ls = {
                    'id': lin.id,
                    'name': lin.name,
                    'default_code': lin.default_code,
                    'uom_id': lin.uom_id.id,
                    'list_price': lin.list_price,
                    'cost_price': lin.standard_price,
                    'categ_id': lin.categ_id.id
                }
                datalist.append(ls)
        else:
            ls = {
                'id': self.id,
                'name': self.name,
                'default_code': self.default_code,
                'uom_id': self.uom_id.id,
                'list_price': self.list_price,
                'cost_price': self.standard_price,
                'categ_id': self.categ_id.id
            }
            datalist.append(ls)
        data = {
            'model_name': self.env.context.get('active_model'),
            'data':  json.dumps({
                'datalist': datalist
            })
        }

        r = requests.post('http://localhost:4000/tampildata', data = data)
        # r = requests.get('http://localhost:4000/tampil', verify=False)
        print (r.json())