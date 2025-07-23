from schema import Schema, Optional, Or
from odoo.http import request
from odoo import http

QUERY = '{id, session_date, participant_id, participant_code, day_date, \
    day_turnover, day_fee, night_date, night_turnover, night_fee, \
    day_market_ids, night_market_ids}'


class PTSGroupAPI(http.Controller):

    @http.route(
        '/jnx16/pts_trade_data',
        type='json-api', auth='api_key', methods=['POST'], csrf=False)
    def postPTSTradeData(self, **params):
        base_rule = rules = Schema({
            "session_date": str,
            "participant_id": int,
            "participant_code": str,
            "day_date": str,
            "day_turnover": float,
            "day_fee": float,
            "night_date": str,
            "night_turnover": float,
            "night_fee": float,
            Optional("day_market_ids"): Or(list, str),
            Optional("night_market_ids"): Or(list, str),
        }, ignore_extra_keys=True)

        participant_ids = []
        for line in params.get('participant_items'):
            get_participant_id = request.env['res.partner'].sudo().search([
                (
                    'pts_trading_participant_code',
                    '=',
                    line.get('participant_code')
                )
            ]).id
            if not get_participant_id:
                raise Exception(
                    'Participant is not found || Code: %s' % line.get(
                        'participant_code'))

            day_markets = []
            for day in line.get('day_trade'):
                market_list_ids = []
                if day.get('market_lists'):
                    i = 0
                    for mar in day.get('market_lists'):
                        get_market_id = request.env['pts.market'].sudo()\
                            .search([
                                ('name', '=', mar.get('market_name')),
                                ('is_night', '=', False)
                            ]).id
                        if not get_market_id:
                            get_market_id = request.env['pts.market'] \
                                .sudo().create({
                                    'name': mar.get('market_name'),
                                    'is_night': False
                                }).id

                        if not mar.get('turnover') or \
                                mar.get('turnover') == '':
                            turnover = float(0)
                        else:
                            turnover = float(mar.get('turnover'))

                        if not mar.get('fee') or mar.get('fee') == '':
                            fee = float(0)
                        else:
                            fee = float(mar.get('fee'))

                        market_list_ids.append((0, 0, {
                            'market_id': get_market_id,
                            'turnover': turnover,
                            'fee': fee,
                            'participant_id': get_participant_id,
                        }))
                        # optional fields input
                        if mar.get('aggregate_group'):
                            get_dlp_id = request.env['pts.dlp.group'] \
                                .sudo().search([
                                    ('name', '=', mar.get('aggregate_group'))
                                ]).id
                            if not get_dlp_id:
                                get_dlp_id = request.env['pts.dlp.group'] \
                                    .sudo().create({
                                        'name': mar.get('aggregate_group')
                                    }).id
                            market_list_ids[i][2].update({
                                'aggregate_group_id': get_dlp_id
                            })

                        if mar.get('group'):
                            get_group_id = request.env['pts.group'] \
                                .sudo().search([
                                    ('name', '=', mar.get('group'))
                                ]).id
                            if not get_group_id:
                                get_group_id = request.env['pts.group'] \
                                    .sudo().create({
                                        'name': mar.get('group')
                                    }).id
                            market_list_ids[i][2].update({
                                'group_id': get_group_id
                            })

                        if mar.get('option'):
                            market_list_ids[i][2].update({
                                'option': mar.get('option')
                            })
                        i += 1

                if not day.get('data_handling_turnover') or \
                        day.get('data_handling_turnover') == '':
                    data_handling_turnover = float(0)
                else:
                    data_handling_turnover = float(
                        day.get('data_handling_turnover')
                    )

                if not day.get('data_handling_fee') or \
                        day.get('data_handling_fee') == '':
                    data_handling_fee = float(0)
                else:
                    data_handling_fee = float(day.get('data_handling_fee'))

                day_markets.append({
                    'day_date': day.get('day_date'),
                    'day_turnover': data_handling_turnover,
                    'day_fee': data_handling_fee,
                    'day_market_ids': market_list_ids,
                })

            night_markets = []
            for night in line.get('night_trade'):
                market_list_ids = []
                if night.get('market_lists'):
                    i = 0
                    for mar in night.get('market_lists'):
                        get_market_id = request.env['pts.market'].sudo()\
                            .search([
                                ('name', '=', mar.get('market_name')),
                                ('is_night', '=', True)
                            ]).id
                        if not get_market_id:
                            get_market_id = request.env['pts.market'] \
                                .sudo().create({
                                    'name': mar.get('market_name'),
                                    'is_night': True
                                }).id

                        if not mar.get('turnover') or \
                                mar.get('turnover') == '':
                            turnover = float(0)
                        else:
                            turnover = float(mar.get('turnover'))

                        if not mar.get('fee') or mar.get('fee') == '':
                            fee = float(0)
                        else:
                            fee = float(mar.get('fee'))

                        market_list_ids.append((0, 0, {
                            'market_id': get_market_id,
                            'turnover': turnover,
                            'fee': fee,
                            'participant_id': get_participant_id
                        }))

                        # optional fields input
                        if mar.get('aggregate_group'):
                            get_dlp_id = request.env['pts.dlp.group'] \
                                .sudo().search([
                                    ('name', '=', mar.get('aggregate_group'))
                                ]).id
                            if not get_dlp_id:
                                get_dlp_id = request.env['pts.dlp.group'] \
                                    .sudo().create({
                                        'name': mar.get('aggregate_group')
                                    }).id
                            market_list_ids[i][2].update({
                                'aggregate_group_id': get_dlp_id
                            })

                        if mar.get('group'):
                            get_group_id = request.env['pts.group'] \
                                .sudo().search([
                                    ('name', '=', mar.get('group'))
                                ]).id
                            if not get_group_id:
                                get_group_id = request.env['pts.group'] \
                                    .sudo().create({
                                        'name': mar.get('group')
                                    }).id
                            market_list_ids[i][2].update({
                                'group_id': get_group_id
                            })

                        if mar.get('option'):
                            market_list_ids[i][2].update({
                                'option': mar.get('option')
                            })
                        i += 1

                if not night.get('data_handling_turnover') or \
                        night.get('data_handling_turnover') == '':
                    night_turnover = float(0)
                else:
                    night_turnover = float(
                        night.get('data_handling_turnover')
                    )

                if not night.get('data_handling_fee') or \
                        night.get('data_handling_fee') == '':
                    night_fee = float(0)
                else:
                    night_fee = float(night.get('data_handling_fee'))
                night_markets.append({
                    'night_date': night.get('night_date'),
                    'night_turnover': night_turnover,
                    'night_fee': night_fee,
                    'night_market_ids': market_list_ids,
                })

            participant_ids.append({
                'session_date': params.get('session_date'),
                'participant_id': get_participant_id,
                'participant_code': line.get('participant_code'),
                'day_date': day_markets[0].get('day_date'),
                'day_turnover': day_markets[0].get('day_turnover'),
                'day_fee': day_markets[0].get('day_fee'),
                'night_date': night_markets[0].get('night_date'),
                'night_turnover': night_markets[0].get('night_turnover'),
                'night_fee': night_markets[0].get('night_fee'),
                'day_market_ids': day_markets[0].get('day_market_ids'),
                'night_market_ids': night_markets[0].get('night_market_ids'),
            })

        model = request.env['pts.trading.info']
        rules = Schema(Or(
            Schema(base_rule, error="Didn't match the requirements"),
            Schema(
                {"data": [base_rule]},
                ignore_extra_keys=True,
                error="Didn't match list requirements")
        ), error="Something go wrong")
        overwrites = {}
        allow_partial = 'allow_partial' in params

        if len(participant_ids) > 1:
            i = 0
            while i < len(participant_ids):
                model.post_record(
                    participant_ids[i], rules, overwrites, data_key="data",
                    allow_partial=allow_partial, query=QUERY)
                i += 1
            return {
                "success": "202",
                "result": "",
                "error_code": "000",
                "error_message": ""
            }
        else:
            return model.post_record(
                    participant_ids[0], rules, overwrites, data_key="data",
                    allow_partial=allow_partial, query=QUERY)
