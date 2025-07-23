from schema import Schema, Optional, Or
from odoo.http import request
from odoo import http
import logging

_logger = logging.getLogger(__name__)
QUERY = '{id, participant_id, participant_code, market_id, dlp_group_id,\
    group_id, make_rate, take_rate, start_date, end_date}'


class PTSGroupAPI(http.Controller):

    @http.route(
        '/jnx16/pts_group',
        type='json-api', auth='api_key', methods=['POST'], csrf=False)
    def postPTSGroupRate(self, **params):
        base_rule = rules = Schema({
            "participant_id": int,
            "participant_code": str,
            "market_id": int,
            "dlp_group_id": int,
            "group_id": int,
            "make_rate": float,
            "take_rate": float,
            "start_date": str,
            "end_date": str,
        }, ignore_extra_keys=True)

        model = request.env['pts.group.rate']
        rules = Schema(Or(
            Schema(base_rule, error="Didn't match the requirements"),
            Schema(
                {"data": [base_rule]},
                ignore_extra_keys=True,
                error="Didn't match list requirements")
        ), error="Something go wrong")
        overwrites = {}
        allow_partial = 'allow_partial' in params

        if params.get('list'):
            for data in params.get('list'):
                exist_data = self.existing_data_checking(data)
                if exist_data:
                    exist_data.write({
                        'make_rate': data.get('make_rate'),
                        'take_rate': data.get('take_rate'),
                        'end_date': data.get('end_date')
                    })
                    _logger.info('Data pts_group updated %s' % exist_data.ids)
                else:
                    post_data = self.get_values_from_params(data)
                    model.post_record(
                        post_data, rules, overwrites, data_key="data",
                        allow_partial=allow_partial, query=QUERY)
                    _logger.info('Data pts_group inserted')
            return {
                "success": "202-Success",
                "result": "Data inserted",
                "error_code": "000",
                "error_message": ""
            }
        else:
            exist_data = self.existing_data_checking(params)
            if exist_data:
                exist_data.write({
                    'make_rate': params.get('make_rate'),
                    'take_rate': params.get('take_rate'),
                    'end_date': params.get('end_date')
                })
                _logger.info('Data pts_group updated %s' % exist_data.ids)
                return {
                    "success": "202 - Success",
                    "result": "Data updated with id %s" % exist_data.ids,
                    "error_code": "000",
                    "error_message": ""
                }
            else:
                post_data = self.get_values_from_params(params)
                _logger.info('Data pts_group inserted')
                return model.post_record(
                    post_data, rules, overwrites, data_key="data",
                    allow_partial=allow_partial, query=QUERY)

    def get_values_from_params(self, params):
        get_participant_id = request.env['res.partner'].sudo().search([
            (
                'pts_trading_participant_code',
                '=',
                params.get('participant_code')
            )
            ]).id
        get_market_id = request.env['pts.market'].sudo().search([
            ('name', '=', params.get('market_name')),
            ('is_night', '=', False)
            ]).id
        get_dlp_group_id = request.env['pts.dlp.group'].sudo().search([
            ('name', '=', params.get('dlp_group'))
            ]).id
        get_group_id = request.env['pts.group'].sudo().search([
            ('name', '=', params.get('group'))
            ]).id

        if not get_participant_id:
            raise Exception('Participant is not found')
        if not get_market_id:
            get_market_id = request.env['pts.market'].sudo().create({
                'name': params.get('market_name'),
                'is_night': False
            }).id
        if not get_dlp_group_id:
            get_dlp_group_id = request.env['pts.dlp.group'].sudo().create({
                'name': params.get('dlp_group')
            }).id
        if not get_group_id:
            get_group_id = request.env['pts.group'].sudo().create({
                'name': params.get('group')
            }).id
        if params.get('make_rate') == '':
            make_rate = float(0)
        else:
            make_rate = float(params.get('make_rate'))
        if params.get('take_rate') == '':
            take_rate = float(0)
        else:
            take_rate = float(params.get('take_rate'))

        params.update({
            'participant_id': get_participant_id,
            'market_id': get_market_id,
            'dlp_group_id': get_dlp_group_id,
            'group_id': get_group_id,
            'make_rate': make_rate,
            'take_rate': take_rate,
        })
        post_data = params.copy()
        del post_data['market_name']
        del post_data['dlp_group']
        del post_data['group']
        return post_data

    def existing_data_checking(self, params):
        participant_obj = request.env['res.partner'].sudo().search([
            (
                'pts_trading_participant_code',
                '=',
                params.get('participant_code')
            )
        ]).id
        pts_market_obj = request.env['pts.market'].sudo().search([
            ('name', '=', params.get('market_name')),
            ('is_night', '=', False)
        ]).id
        pts_dlp_group_obj = request.env['pts.dlp.group'].sudo().search([
            ('name', '=', params.get('dlp_group'))
        ]).id
        pts_group_obj = request.env['pts.group'].sudo().search([
            ('name', '=', params.get('group'))
        ]).id

        if request.env['pts.group.rate'].search([
                ('participant_id', '=', participant_obj),
                ('market_id', '=', pts_market_obj),
                ('dlp_group_id', '=', pts_dlp_group_obj),
                ('group_id', '=', pts_group_obj),
                ('start_date', '=', params.get('start_date'))
                ]):
            return request.env['pts.group.rate'].search([
                ('participant_id', '=', participant_obj),
                ('market_id', '=', pts_market_obj),
                ('dlp_group_id', '=', pts_dlp_group_obj),
                ('group_id', '=', pts_group_obj),
                ('start_date', '=', params.get('start_date'))
            ])
        else:
            return False
