import logging

from odoo import SUPERUSER_ID, models
from odoo.http import request
from ..controllers.http import JsonApiException

_logger = logging.getLogger(__name__)


class IrHttp(models.AbstractModel):
    _inherit = "ir.http"

    @classmethod
    def _auth_method_root(cls):
        request.update_env(user=SUPERUSER_ID)

    @classmethod
    def _auth_method_api_key(cls):
        """ Function to enable Authentification on the API

        Match the API key received from X-Odoo-Api-Key to verify if the it exist and can access the endpoint
        :param self:                    The current record.
        :param endpoint:                The current enpoint use by Odoo.

        :return:                        None.
        The user of the environement is updated with the one specify on the API key

        You can setup the API key in Settings > API Information > API Configuration
        """
        received_api_key = request.httprequest.environ.get("HTTP_X_ODOO_API_KEY")
        endpoint = request.httprequest.full_path.strip('?')
        # Check API KEY
        api_handler_env = request.env['pci.api.handler'].sudo()
        configuration_api_key = api_handler_env.search([
            ('incoming_api_key', '=', received_api_key)])

        _logger.debug(f"Check API keys - Recieved: {received_api_key} -- Source: {configuration_api_key} -- Endpoints: {configuration_api_key.endpoints} -- Is Root: {configuration_api_key.root_user} -- User: {configuration_api_key.user_id.name}")

        if not configuration_api_key:
            raise JsonApiException(
                msg='Failed authentification',
                hint="Check your API key",
                code=401)

        if not configuration_api_key.is_authorized_endpoint(endpoint):
            raise JsonApiException(
                msg='Endpoint not authorized',
                hint="Check the enpoint authorized by your API key",
                code=403)

        if configuration_api_key.root_user:
            uid = SUPERUSER_ID
        else:
            uid = configuration_api_key.user_id.id

        request.update_env(user=uid)
