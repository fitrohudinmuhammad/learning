from odoo import _, api, fields, models


class TableReport(models.Model):
    _name = "table.report"
    _description = "Table Report"
    _order = 'specific_date'

    specific_date = fields.Date(string="Date", readonly=True)
    minutes_utilized = fields.Float(string="Minutes Utilized", readonly=True)
    percentage_of_utilization = fields.Float(default="0", readonly=True)
    minutes_idle = fields.Float(readonly=True)
    percentage_of_idle = fields.Float(default="100", readonly=True)
    tablea_id = fields.Many2one('table.a', 'TableA', readonly=True)

    def _query(self):
        query = """
            WITH tbl as (SELECT MIN(id) AS id,
                day::date as specific_date,
                SUM(CASE 
                    WHEN date_trunc('day', day) = date_trunc('day', ((start_date at time zone 'UTC') at time zone 'ICT')) 
                        AND date_trunc('day', day ) = date_trunc('day', ((end_date at time zone 'UTC') at time zone 'ICT'))
                    THEN extract(hour from ((end_date at time zone 'UTC') at time zone 'ICT') - ((start_date at time zone 'UTC') at time zone 'ICT')) * 60 + extract(minute from (((end_date at time zone 'UTC') at time zone 'ICT') - ((start_date at time zone 'UTC') at time zone 'ICT')))
                    WHEN date_trunc('day', day) = date_trunc('day', ((start_date at time zone 'UTC') at time zone 'ICT')) 
                        AND date_trunc('day', day) != date_trunc('day', ((end_date at time zone 'UTC') at time zone 'ICT'))
                    THEN extract(hour from (day + interval '23 hour 59 minute') - ((start_date at time zone 'UTC') at time zone 'ICT')) * 60 + extract(minute from (day + interval '23 hour 59 minute') - ((start_date at time zone 'UTC') at time zone 'ICT'))
                    WHEN date_trunc('day', day) != date_trunc('day', ((start_date at time zone 'UTC') at time zone 'ICT'))
                        AND date_trunc('day', day) = date_trunc('day', ((end_date at time zone 'UTC') at time zone 'ICT')) 
                    THEN extract(hour from ((end_date at time zone 'UTC') at time zone 'ICT') - day) * 60 + extract(minute from day)
                ELSE 1440 END) as minutes_utilized, 
                tablea_id
            FROM table_b, 
                generate_series(date_trunc('day', ((start_date at time zone 'UTC') at time zone 'ICT')), date_trunc('day', ((end_date at time zone 'UTC') at time zone 'ICT')), interval '1 day') AS day
            WHERE tablea_id is not null
            GROUP BY day, tablea_id
            ORDER BY day)

            SELECT 
                id,
                specific_date as specific_date, 
                minutes_utilized as minutes_utilized, 
                minutes_utilized / 1440 as percentage_of_utilization, 
                1440 - minutes_utilized as minutes_idle,
                (1440 - minutes_utilized) / 1440 as percentage_of_idle,
                tablea_id
            FROM tbl
        """
        return f"""{query}"""

    def _nquery(self):
        query = """
            SELECT 
                id, 
                day::date as specific_date, 
                0 as minutes_utilized, 
                0 as minutes_idle, 
                0 as percentage_of_utilization, 
                0 as percentage_of_idle,
                tablea_id
            FROM table_b, 
                generate_series(date_trunc('day', start_date + interval '7 hour'), date_trunc('day', end_date + interval '7 hour'), interval '1 day') AS day
        """
        return f"""{query}"""

    @property
    def _table_query(self):
        return '%s' % self._query()
