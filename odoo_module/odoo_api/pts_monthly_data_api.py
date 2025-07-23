from schema import Schema, Optional, Or
from odoo.http import request
from odoo import http

QUERY = '{id, date, participant_id, rec_type, market_id, dlp_group_id, \
    group_id, make_take, turnover, rate, amount}'


class PTSGroupAPI(http.Controller):

    @http.route(
        '/jnx16/pts_monthly_data',
        type='json-api', auth='api_key', methods=['POST'], csrf=False)
    def postPTSCommissionParameter(self, **params):
        base_rule = rules = Schema({
            "date": str,
            "participant_id": int,
            "rec_type": str,
            "market_id": int,
            "dlp_group_id": int,
            "group_id": int,
            "make_take": str,
            "turnover": float,
            "rate": float,
            "amount": float
        }, ignore_extra_keys=True)

        model = request.env['pts.trading.monthly.detail']
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
                post_data = self.get_values_from_params(data)
                model.post_record(
                    post_data[0], rules, overwrites, data_key="data",
                    allow_partial=allow_partial, query=QUERY)
            return {
                "success": "202",
                "result": "Data inserted",
                "error_code": "000",
                "error_message": ""
            }
        else:
            post_data = self.get_values_from_params(params)
            return model.post_record(
                post_data[0], rules, overwrites, data_key="data",
                allow_partial=allow_partial, query=QUERY)

    def get_values_from_params(self, params):
        get_participant_id = request.env['res.partner'].sudo().search([
            (
                'pts_trading_participant_code',
                '=',
                params.get('participant_code')
            )
        ]).id

        if not get_participant_id:
            raise Exception('Participant is not found')

        get_market_id = request.env['pts.market'].sudo().search([
            ('name', '=', params.get('aggregation_class')),
            ('is_night', '=', False)
        ]).id
        if not get_market_id:
            get_market_id = request.env['pts.market'].sudo().create({
                'name': params.get('aggregation_class'),
                'is_night': False
            }).id

        get_dlp_group_id = request.env['pts.dlp.group'].sudo().search([
            ('name', '=', params.get('aggregation_group'))
        ]).id
        if not get_dlp_group_id:
            get_dlp_group_id = request.env['pts.dlp.group'].sudo().create({
                'name': params.get('aggregation_group')
            }).id

        get_group_id = request.env['pts.group'].sudo().search([
            ('name', '=', params.get('aggregation_subclass'))
        ]).id
        if not get_group_id:
            get_group_id = request.env['pts.group'].sudo().create({
                'name': params.get('aggregation_subclass')
            }).id

        turnover = float(0) if params.get('quantity') == '' \
            else float(params.get('quantity'))
        rate = float(0) if params.get('rate') == '' \
            else float(params.get('rate'))
        amount = float(0) if params.get('amount') == '' \
            else float(params.get('amount'))

        make_take = ''
        if params.get('aggregation_maketake'):
            make_take = params.get('aggregation_maketake').lower()
        rec_type = ''
        if params.get('rec_type'):
            if params.get('rec_type') == 'MM':
                rec_type = 'mm'
            else:
                rec_type = 'mm_total'

        post_data = []
        post_data.append({
            "date": params.get('aggregate_month'),
            "participant_id": get_participant_id,
            "rec_type": rec_type,
            "market_id": get_market_id,
            "dlp_group_id": get_dlp_group_id,
            "group_id": get_group_id,
            "make_take": make_take,
            "turnover": turnover,
            "rate": rate,
            "amount": amount
        })
        return post_data
