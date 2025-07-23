from psycopg2 import IntegrityError

from odoo.http import request, Dispatcher, serialize_exception
from odoo.exceptions import ValidationError, MissingError

from .utils import log_request
from .exceptions import JsonApiException

JSON_MIMETYPES = ('application/json', '')


class JsonAPIDispatcher(Dispatcher):
    routing_type = 'json-api'

    @classmethod
    def is_compatible_with(cls, request):
        return request.httprequest.mimetype in JSON_MIMETYPES

    def dispatch(self, endpoint, args):
        raise_error_default = False
        try:
            jsonrequest = self.request.get_json_data()
        except ValueError:
            jsonrequest = {}

        data = dict(jsonrequest, **args)
        # This is to enable legacy support when migrating from 15.0 to 16.0 and use the params key
        if endpoint.original_routing.get("legacy", False):
            data = data.get('params', {})
        self.request.params = data
        ctx = self.request.params.pop('context', None)
        if ctx is not None and self.request.db:
            self.request.update_env(context=ctx)

        log_req = endpoint.original_routing.get("log_req", True)
        httprequest = request.httprequest
        # request_type = request._request_type
        api_endpoint = httprequest.full_path
        dbname = request.db
        # format of log_message. Ex: 'Method: http POST - 200: OK'
        log_message = f'Method: {httprequest.method} - %s: %s'
        try:
            if self.request.db:
                result = self.request.registry['ir.http']._dispatch(endpoint)
            else:
                result = endpoint(**self.request.params)

            if log_req:
                code = 200
                msg = "OK"
                log_request(api_endpoint, str(self.request.params), dbname, log_message % (code, msg), "success")
        except Exception as err:
            if isinstance(err, JsonApiException):
                code = err.code
                msg = err.msg
                hint = err.hint
            elif isinstance(err, ValidationError):
                code = 404
                msg = str(err)
                hint = "Check the request body"
            elif isinstance(err, IntegrityError):
                code = 404
                msg = str(err)
                hint = "The record seems to be existing"
            elif isinstance(err, MissingError):
                code = 404
                msg = "Not found"
                hint = str(err)
            else:
                code = 500
                raise_error_default = True

            if log_req:
                log_request(api_endpoint, str(self.request.params), dbname, log_message % (code, err), 'fail')

            if raise_error_default:
                raise

            raise JsonApiException(msg=msg, hint=hint, code=code) from err

        return self._response(result)

    def handle_error(self, exc):
        error = {
            'message': "Odoo Server Error",
            'hint': f"Unexpected error happened {exc}",
            'http_code': 500,
        }
        debug = request.httprequest.args.get('debug')
        if debug:
            error['debug'] = serialize_exception(exc)

        if isinstance(exc, JsonApiException):
            error['http_code'] = exc.code
            error['message'] = exc.msg
            error['hint'] = exc.hint

        return self._response(error=error)

    def _response(self, result=None, error=None):
        response = {}
        http_code = 204
        if error:
            http_code = error.pop("http_code", 500)
            response = {"status": "error", **error}

        if result is not None:
            http_code = result.get("http_code", 200)
            response = {
                "status": "success",
                "result": result.get("result")
            }
            msg = result.get("msg")
            if msg:
                response["message"] = msg

        return self.request.make_json_response(response, status=http_code)
