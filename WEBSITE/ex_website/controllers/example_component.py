import json
import pytz
import odoo.http as http
from odoo.http import request
from datetime import datetime

class ExampleComponent(http.Controller):

    @http.route(['/example-pages/1/card1'], type='http', auth='public', website=True, sitemap=False)
    def component_card1(self, **kwargs):
        return request.render("ex_website.card1")

    @http.route(['/example-pages/1/card2'], type='http', auth='public', website=True, sitemap=False)
    def component_card2(self, **kwargs):
        return request.render("ex_website.card2")

    @http.route(['/example-pages/1/card3'], type='http', auth='public', website=True, sitemap=False)
    def component_card3(self, **kwargs):
        return request.render("ex_website.card3")
