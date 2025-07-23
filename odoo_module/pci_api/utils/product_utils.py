from typing import Any
from ..common import resource_formater as common_formatter


class ProductAttributeValueDataIn(common_formatter.DataTrans):
    def __call__(self, option_id, option_value):
        data = []
        if 'id' in option_value:
            data += self._update_option_value(option_value)
        else:
            data += self._create_option_value(option_id, option_value)
        return data

    @classmethod
    def _update_option_value(cls, option_value):
        return [(4, option_value['id'])]

    @classmethod
    def _create_option_value(cls, option_id, option_value):
        return [(0, 0, {'attribute_id': option_id, 'name': option_value['name']})]


class ProductAttributeDataIn(common_formatter.DataTrans):

    transform_option_value = ProductAttributeValueDataIn()
    env: Any

    def __init__(self, env):
        self.env = env

    def __call__(self, options, key, **kwargs):
        data = []
        option_values = []
        for option in options:
            attribute = self.env['product.attribute'].search([('name', '=', option['name'])], limit=1)
            if not attribute:
                attribute = attribute.sudo().create({'name': option['name']})
            for option_value in option['values']:
                option_values += self.transform_option_value(attribute.id, option_value)
            if 'id' in option:
                data += self._update_option(option, option_values)
            else:
                data += self._create_option(attribute, option_values)
        return key, data

    def _update_option(self, option, option_values):
        return [(1, option['id'], {'value_ids': option_values})]

    def _create_option(self, attribute, option_values):
        return [(0, 0, {'attribute_id': attribute.id, 'value_ids': option_values})]
