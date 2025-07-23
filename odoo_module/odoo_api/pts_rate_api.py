from schema import Schema, Optional, Or
from odoo.http import request
from odoo import http
import logging

_logger = logging.getLogger(__name__)
QUERY = '{id, participant_id, participant_code, start_date, end_date, \
    membership_day, membership_night, rate_day, rate_night, \
    transaction_fee_ids}'


class PTSGroupAPI(http.Controller):

    @http.route(
        '/jnx16/pts_rate',
        type='json-api', auth='api_key', methods=['POST'], csrf=False)
    def postPTSCommissionParameter(self, **params):
        base_rule = rules = Schema({
            "participant_id": int,
            "participant_code": str,
            "start_date": str,
            "end_date": str,
            "membership_day": float,
            "membership_night": float,
            "rate_day": float,
            "rate_night": float,
            Optional("transaction_fee_ids"): Or(list, str),
        }, ignore_extra_keys=True)

        model = request.env['pts.commission.parameter']
        rules = Schema(Or(
            Schema(base_rule, error="Didn't match the requirements"),
            Schema(
                {"data": [base_rule]},
                ignore_extra_keys=True,
                error="Didn't match list requirements")
        ), error="Something go wrong")
        overwrites = {}
        allow_partial = 'allow_partial' in params

        transaction_mdl = request.env['pts.transaction.fee.line']
        market_mdl = request.env['pts.market']
        if params.get('list'):
            for data in params.get('list'):
                exist_data = self.existing_data_checking(data)
                if exist_data:
                    market_names = []
                    for nm in exist_data.transaction_fee_ids:
                        market_names.append(nm.market_id.name)
                    for comrat in data.get('commission_rate'):
                        if comrat.get('market_name') in market_names:
                            transaction_mdl.search([
                                (
                                    'market_id.name',
                                    '=',
                                    comrat.get('market_name')),
                                ('market_id.is_night', '=', False),
                                ('commission_parameter_id', '=', exist_data.id)
                            ]).write({
                                'fee': comrat.get('rate')
                            })
                        else:
                            if market_mdl.search([
                                    ('name', '=', comrat.get('market_name')),
                                    ('is_night', '=', False)]):
                                mrkt_id = market_mdl.search([
                                    ('name', '=', comrat.get('market_name')),
                                    ('is_night', '=', False)]).id
                            else:
                                mrkt_id = market_mdl.create({
                                    'name': comrat.get('market_name')
                                }).id
                            transaction_mdl.create({
                                'market_id': mrkt_id,
                                'fee': comrat.get('rate'),
                                'commission_parameter_id': exist_data.id
                            })
                    _logger.info('Data pts_rate updated %s' % exist_data.ids)
                else:
                    post_data = self.get_values_from_params(data)
                    model.post_record(
                        post_data, rules, overwrites, data_key="data",
                        allow_partial=allow_partial, query=QUERY)
            return {
                "success": "202",
                "result": "Data inserted",
                "error_code": "000",
                "error_message": ""
            }
        else:
            exist_data = self.existing_data_checking(params)
            if exist_data:
                market_names = []
                for nm in exist_data.transaction_fee_ids:
                    market_names.append(nm.market_id.name)
                for line in params.get('commission_rate'):
                    if line.get('market_name') in market_names:
                        transaction_mdl.search([
                            ('market_id.name', '=', line.get('market_name')),
                            ('market_id.is_night', '=', False),
                            ('commission_parameter_id', '=', exist_data.id)
                        ]).write({
                            'fee': line.get('rate')
                        })
                    else:
                        if market_mdl.search([
                                ('name', '=', line.get('market_name')),
                                ('is_night', '=', False)]):
                            mrkt_id = market_mdl.search([
                                ('name', '=', line.get('market_name')),
                                ('is_night', '=', False)]).id
                        else:
                            mrkt_id = market_mdl.create({
                                'name': line.get('market_name')
                            }).id
                        transaction_mdl.create({
                            'market_id': mrkt_id,
                            'fee': line.get('rate'),
                            'commission_parameter_id': exist_data.id
                        })
                _logger.info('Data pts_rate updated %s' % exist_data.ids)
                return {
                    "success": "202 - Success",
                    "result": "Data updated with id %s" % exist_data.ids,
                    "error_code": "000",
                    "error_message": ""
                }
            else:
                post_data = self.get_values_from_params(params)
                _logger.info('Data pts_rate inserted')
                return model.post_record(
                    post_data, rules, overwrites, data_key="data",
                    allow_partial=allow_partial, query=QUERY)

    def get_values_from_params(self, params):
        get_participant_id = request.env['res.partner'].search([
            (
                'pts_trading_participant_code',
                '=',
                params.get('participant_code')
            )
        ]).id

        if not get_participant_id:
            raise Exception('Participant is not found')

        new_transaction_fee_ids = []
        for line in params.get('commission_rate'):
            get_market_id = request.env['pts.market'].search([
                ('name', '=', line.get('market_name')),
                ('is_night', '=', False)
            ]).id
            if not get_market_id:
                get_market_id = request.env['pts.market'].create({
                    'name': line.get('market_name'),
                    'is_night': False
                }).id
            new_transaction_fee_ids.append((0, 0, {
                'market_id': get_market_id,
                'fee': float(line.get('rate'))
            }))

        membership_day = float(0) if params.get('membership_day') == '' \
            else float(params.get('membership_day'))
        membership_night = float(0) if params.get('membership_night') == '' \
            else float(params.get('membership_night'))
        rate_day = float(0) if params.get('commission_rate_day') == '' \
            else float(params.get('commission_rate_day'))
        rate_night = float(0) if params.get('commission_rate_night') == '' \
            else float(params.get('commission_rate_night'))
        params.update({
            'participant_id': get_participant_id,
            'transaction_fee_ids': new_transaction_fee_ids,
            'membership_day': membership_day,
            'membership_night': membership_night,
            'rate_day': rate_day,
            'rate_night': rate_night,
        })
        post_data = params.copy()
        del post_data['commission_rate_day']
        del post_data['commission_rate_night']
        del post_data['commission_rate']
        return post_data

    def existing_data_checking(self, params):
        participant_obj = request.env['res.partner'].search([
            (
                'pts_trading_participant_code',
                '=',
                params.get('participant_code')
            )
        ]).id
        pts_market_obj = request.env['pts.market'].search([
            ('name', '=', params.get('market_name')),
            ('is_night', '=', False)
        ]).id
        pts_dlp_group_obj = request.env['pts.dlp.group'].search([
            ('name', '=', params.get('dlp_group'))
        ]).id
        pts_group_obj = request.env['pts.group'].search([
            ('name', '=', params.get('group'))
        ]).id

        if request.env['pts.commission.parameter'].search([
                ('participant_id', '=', participant_obj),
                ('start_date', '=', params.get('start_date'))
                ]):
            return request.env['pts.commission.parameter'].search([
                ('participant_id', '=', participant_obj),
                ('start_date', '=', params.get('start_date'))
            ])
        else:
            return False
