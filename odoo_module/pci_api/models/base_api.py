import json
import math
from schema import SchemaError

from odoo import models, fields, api, _, exceptions, registry
from odoo.addons.pci_api.controllers.exceptions import QueryFormatError, JsonApiException
from odoo.addons.pci_api.controllers.serializers import Serializer


class BaseAPI(models.AbstractModel):
    """
    This this the heart of the module - you will need to inherit this model to model you want to enable API.
    After inheriting the module you will have access to 4 main function:
     - get_record - allow to get a list of records
     - get_one_record - allow to get one record
     - post_record - allow to create one or multiple records
     - put record - allow to edit one or multiple records
     - post_obj_function - allow you to call a custom function
    """
    _name = "base.api"
    _description = "Base API"

    created_by_api = fields.Boolean()

    @api.model
    def get_record(self, query, params, default_order='', default_filter=[]):
        """ Function to list record from a model and formated to JSON list
        :param self:              An empty recordset of the model.
        :param query:             A format that allow fetch the field wanted in the record - Check Explanation bellow
        :param params:            Params received on the controler - Check Explanation bellow
        :param default_order:     Force the order wanted to be return, use default string of odoo
        :param default_filter:    Force a default filter on the record

        :return: http.Response

        * query explanation:
        The query is here to fetch the exact field wanted from the record. The query give you the possibility to define the name of the key return in the JSON.
        The best to explain is examples:
        The basic where you can overwrite some keys from Odoo
        ```
        query = '(id:lead_id, partner_id:customer_id) {id, name, partner_id, email_from}'
        result = {
            "lead_id": 1,
            "name": "hello",
            "customer_id": 123,
            "email_from": "aa@aa.aa",
        }
        ```

        You can also define the fields from the different relation model and go deep in to the tree
        ```
        query = '(id:lead_id, partner_id:partner) {id, name, partner_id (child_ids:addresses) {name, email, child_ids {street, city, zip, country_id}}, email_from}'
        result = {
            "lead_id": 1,
            "name": "hello",
            "partner": {
                "name": "Hello",
                "email": "aa@aa.aa",
                "addresses": [
                    {
                        "street": "1 street",
                        "city": "city 1",
                        "zip": "11111",
                        "country_id": 100
                    },
                    {
                        "street": "2 street",
                        "city": "city 2",
                        "zip": "222222",
                        "country_id": 200
                    }
                ]
            },
            "email_from": "aa@aa.aa",
        }
        ```

        You can also define a function to filter the records from a One2many fields or Many2many fields
        ```
        query = '(id:lead_id, partner_id:partner) {id, name, partner_id (child_ids:addresses~filter_some_address) {name, email, child_ids {street, city, zip, country_id}}, email_from}'
        result = {
            "lead_id": 1,
            "name": "hello",
            "partner": {
                "name": "Hello",
                "email": "aa@aa.aa",
                "addresses": [
                    {
                        "street": "1 street",
                        "city": "city 1",
                        "zip": "11111",
                        "country_id": 100
                    },
                ]
            },
            "email_from": "aa@aa.aa",
        }

        in the model of childs_ids that here is 'res.partner' you need to create a function with the following information:
        def filter_some_address(self):
            # you can use any python functionality and return the recordset wanted
            # for example: res = self.filtered(lambda r: r.country_id.code == 'FR')
            return res
        ```

        This method is quite flexible, if you see any other usecase let see how we can implement it - the parser and serialiser is defined in controllers/parser.py and controllers/serializers.py

        * params explanation:
        The params object is from the controler, it contains all the the information from the query string.
        There is couple of query string that the user of the API can defined and are taking in consideration.

         - order: (optional)
            allow to define the order wanted, format of Odoo - field_name ASC/DESC - ex: sequence ASC
            this will overwrite the default_order

         - filter: (optinal)
            allow to filter the result, format of Odoo - [["field_name", "=", "val"]]
            the " are important as we are unsing json.loads
            the filter is added to the default filter with an AND condition

         - page_size: (optional)
            define the number of record wanted per page

         - page: (optinal)
            page that you want to access - first page is 1

         - limit: (optional)
            limit the number the of record

        """
        if "order" in params:
            order = params["order"]
        else:
            order = default_order

        if "filter" in params:
            filters = default_filter + json.loads(params["filter"])
        else:
            filters = default_filter

        try:
            records = self.search(filters, order=order)
        except Exception as err:
            raise exceptions.ValidationError(err)

        prev_page = None
        next_page = None
        total_page_number = 1
        current_page = 1

        if "page_size" in params:
            page_size = int(params["page_size"])
            count = len(records)
            total_page_number = math.ceil(count / page_size)

            if "page" in params:
                current_page = int(params["page"])
            else:
                current_page = 1  # Default page Number
            start = page_size * (current_page - 1)
            stop = current_page * page_size
            records = records[start:stop]
            next_page = current_page + 1 \
                if 0 < current_page + 1 <= total_page_number \
                else None
            prev_page = current_page - 1 \
                if 0 < current_page - 1 <= total_page_number \
                else None

        if "limit" in params:
            limit = int(params["limit"])
            records = records[:limit]

        try:
            serializer = Serializer(records, query, many=True)
            data = serializer.data
        except (SyntaxError, QueryFormatError) as e:
            raise exceptions.ValidationError(str(e))

        res = {
            "count": len(records),
            "prev": prev_page,
            "current": current_page,
            "next": next_page,
            "total_pages": total_page_number,
            "result": data
        }
        return {'result': res}

    @api.model
    def get_one_record(self, query, record_identifier_key, record_identifier_val, operator='='):
        """ Function to fetch one record from a model and formated to JSON object
        :param self:                   An empty recordset of the model.
        :param query:                  A format that allow fetch the field wanted in the record - Check explanation on get_record
        :param record_identifier_key:  The value of the field in Odoo that will be the identifier - ex: id / code /...
        :param record_identifier_val:  The value of the search - ex: 12 for the id
        :param operator:               The operator use in the search - (optinal) - default: =

        :return: http.Response
        """
        domain = [(record_identifier_key, operator, record_identifier_val)]
        try:
            record = self.search(domain, limit=1)
        except Exception as err:
            raise exceptions.ValidationError(err)

        if not record:
            raise JsonApiException(msg='Record not found', code=404)

        try:
            serializer = Serializer(record, query, many=True)
            # we want to keept only the one value as the record should have only one record
            data = serializer.data[0]
        except (SyntaxError, QueryFormatError) as e:
            raise exceptions.ValidationError(str(e))

        return {'result': data}

    @api.model
    def post_record(self, post, rules=None, overwrite={}, data_key=None, query=None, allow_partial=False):
        """ Function to create a new record in a model
        :param self:            An empty recordset of the model.
        :param post:            Contain the information that will create the record/records.
        :param rules:           A Schema object to validate the post information - Check Explanation bellow
        :param overwrite:       An object to define overwrite via a function or string/int/bool - Check Explanation bellow
        :param data_key:        The key is used to get a list as we cannot - Check Explanation bellow
        :param query:           A format that allow fetch the field wanted to be returned - Check Explanation on get_record
        :param allow_partial:   Flag to allow to continue the creation of multiple record even if multiple failed - it will return a warning with the record not created - Check Explanation bellow

        :return: JsonApiResponse

        * Explanation rules
        rules are a Schema base validation that allow to format and check the contain we receive in the post
        Documentation: https://github.com/keleshev/schema
        You can find here some examples:
        ```
        rules = Schema({
                "opportunity_id": int,
                Optional("signature_date", default=fields.Date.today()): str,
                Optional("employee_id", default=None): int,
                "configurations": [
                    Schema({
                        "id": str,
                        "model_id": int,
                        Optional("surface"): Or(int, float),
                        "equipment_id": int,
                        "finition_id": int,
                        "option_ids": [Schema({'id': int, 'qty': Or(int, float)}, ignore_extra_keys=True)],
                        "custom_options": [
                            Schema({
                                Optional("id"): str,
                                Optional("name"): str,
                                "description": str,
                                "qty": Or(int, float),
                                "unit_price": Or(float, int),
                            }, ignore_extra_keys=True)
                        ],
                    }, ignore_extra_keys=True),
                    Schema({
                        "id": str,
                        "model_id": int,
                        "surface": Or(int, float),
                        "option_ids": [Schema({'id': int, 'qty': Or(int, float)}, ignore_extra_keys=True)],
                        "custom_options": [
                            Schema({
                                Optional("id"): str,
                                Optional("name"): str,
                                "description": str,
                                "qty": Or(int, float),
                                "unit_price": Or(float, int),
                            }, ignore_extra_keys=True)
                        ],
                    }, ignore_extra_keys=True)

                ],
                Optional("discount", default=0): Or(float, int)

            }, ignore_extra_keys=True)
        ```

        ```
        rules = Schema({
                "opportunity_id": int,
                "name": str,
                "description": str,
                "start": str,
                Optional("stop", default=add_one_hour(params.get('start'))): str
            }, ignore_extra_keys=True)
        ```

        * Explanation overwrite
        The overwrite object allow you to define a function or string/bool/int/float for the filed
        if you want to define a function you need to use the following format:
        ```
        def overwrite_fucntion(val, key=None, data=None):
            # process
            return modify_key, modify_val
        ```
        with val: the value of the field / key: the key of the field / data: the data receive to create the exact record
        return modify_key: the new value of the key / modify_val: the new value of the val

        example to transform a string to uppercase:
        ```
        def transform_name(name, key=None, data=None):
            if name:
                return key, name.upper()
            else:
                return key, False
        ```
        you can use the helper function `transform_field_value_into_id` in utils/transform.py to easily transfor an indentifier to id

        * Explanation data_key
        The data key is necessary when you want to create multiple record as Odoo does not allow receiving an array directly in the params. So you need to basicaly define a key to define the list.

        * Explanation allow_partial
        This functionality allows not to raise error if one record fails to create and to continue with the reste of the record. If the we create partialy the record then will return a 207 code.

        If there is a usecase not taken in concideration we recommend them to use the function `post_obj_function` where you'll be able define the flow wanted
        """
        validated_data = self.validate_schema(rules, post)

        # Perform action on mutiple raws
        if data_key and validated_data.get(data_key):
            validated_data = validated_data[data_key]

        if not isinstance(validated_data, list):
            validated_data = [validated_data]

        # Overide the value needed
        error = []
        created = []
        for vd in validated_data:
            vd = self._manage_overwrite(vd, overwrite)

            # create a new cursor to
            if allow_partial:
                cr = registry(self._cr.dbname).cursor()
                self = self.with_env(self.env(cr=cr))
            try:
                record = self.with_context({"from_api": True}).create(vd)
                created.append(self._serialise_response(record, query))
            except Exception as e:
                if allow_partial:
                    cr.rollback()
                    error.append({
                        "msg": str(e),
                        "received_data": vd
                    })
                    continue
                raise
            finally:
                if allow_partial:
                    cr.commit()
                    cr.close()

        result, msg, http_code = self._prepare_response_post(created, error, allow_partial)
        return {'result': result, 'msg': msg, 'http_code': http_code}

    def put_record(self, put, rules=None, overwrite={}, data_key=None, query=None):
        """ Function to update a record in the model
        :param self:            One recordset of the model.
        :param put:             Contain the information that will update the record.
        :param rules:           A Schema object to validate the post information - Check Explanation post_record
        :param overwrite:       An object to define overwrite via a function or string/int/bool - Check Explanation post_record
        :param data_key:        The key is used to get a list as we cannot - Check Explanation post_record
        :param query:           A format that allow fetch the field wanted to be returned - Check Explanation on get_record

        :return: JsonApiResponse

        * Explanation update One2many / Many2many fields
        To update the x2many fields you have couple of solution:
         - you can provide a list of ids - we perform a SET (6) from the Odoo ORM
         - you can provide a dictionary with the following key:
           - push: with a list of ids - those ids will be LINK (4)
           - pop: with a list of ids - those ids will be UNLINK (3)
           - delete: with a list of ids - those ids will be DELETE (2)
         - you can use an overwrite function to format the value

        There is a space for improvements let us know your feedback

        :return: JsonApiResponse
        """
        self.ensure_one()
        validated_data = self.validate_schema(rules, put)
        if data_key and validated_data.get(data_key):
            validated_data = validated_data[data_key]

        # Overide the value needed if it exist
        validated_data = self._manage_overwrite(validated_data, overwrite)

        # define strategy for x2many field to change or replace value
        validated_data = self._manage_x2many_fields(validated_data)

        self.with_context({"from_api": True}).write(validated_data)

        result = self._serialise_response(self, query)
        return {'result': result}

    def post_obj_function(self, function, post, rules=None, overwrite={}, data_key=None, ensure_one=True, is_http_route=False):
        """ Function to perform a function toward recordset or a model
        :param self:            Empty/multiple recordset of the model.
        :param function:        Function name that should be executed - Check explanation bellow
        :param post:            Contain the information that will update the record.
        :param rules:           A Schema object to validate the post information - Check explanation post_record
        :param overwrite:       An object to define overwrite via a function or string/int/bool - Check explanation post_record
        :param data_key:        The key is used to get a list as we cannot - Check explanation post_record
        :param ensure_one:      Flag to ensure only one record
        :param is_http_route:   Flag to be able to use the function with a route that has the type = http

        :return: JsonApiResponse

        * Explanation function

        """
        validated_data = self.validate_schema(rules, post)

        if data_key and validated_data.get(data_key):
            validated_data = validated_data[data_key]

        validated_data = self._manage_overwrite(validated_data, overwrite)

        obj = self.with_context({"from_api": True})
        if self and ensure_one:
            obj.ensure_one()

        result = getattr(obj, function)(**validated_data)
        return {'result': result}

    ######
    # Base odoo
    ######

    @api.model
    @api.model_create_multi
    def create(self, val_list):
        for vals in val_list:
            vals.setdefault('created_by_api', self.env.context.get("from_api"))
        return super(BaseAPI, self).create(val_list)

    def write(self, vals):
        vals.setdefault('created_by_api', self.env.context.get("from_api"))
        return super(BaseAPI, self).write(vals)

    ######
    # Helper functions
    ######

    @api.model
    def format_schema_error_reponse(self, e):
        """ Helper function to format schema error"""
        base_error_msg = ""
        linker = " - "
        base_info_message = []
        for err in e.errors:
            if err:
                base_error_msg = err
                break
        prepend = ''
        for info in e.autos:
            if info:
                if info.startswith('Or('):
                    linker = " or "
                    continue
                if "Schema" in info or "And(" in info or 'Optional(' in info:
                    continue

                if info.endswith('error:'):
                    prepend = info
                    continue

                base_info_message.append(prepend + " " + info)
                prepend = ''

        return f"{base_error_msg} / {linker.join(base_info_message)}"

    @api.model
    def _serialise_response(self, record, query):
        """Helper function to Serialize the response"""
        if query:
            try:
                serializer = Serializer(record, query)
                data = serializer.data
            except (SyntaxError, QueryFormatError) as e:
                raise exceptions.ValidationError(str(e))
        else:
            data = record.id

        return data

    @api.model
    def _prepare_response_post(self, created, error, allow_partial):
        """Helper function to prepare reponse on post"""
        if allow_partial:
            result = {"created": created, "error": error}
        else:
            if len(created) == 1:
                result = created[0]
            else:
                result = created

        http_code = 200
        msg = "Record created"
        if error:
            http_code = 207
            msg = "Record Partialy created"

        return [result, msg, http_code]

    @api.model
    def _manage_overwrite(self, data, overwrite):
        """Helper function to apply overwrite"""
        init_data = dict(data)
        for key, value in overwrite.items():
            if callable(value) and key in data:
                k, v = value(data.get(key), key=key, data=init_data)
                data[k] = v
                if k != key:
                    del data[key]
            elif key in data:
                data[key] = value
            else:
                continue

        return data

    # TODO: improve the function
    @api.model
    def _manage_x2many_fields(self, data):
        """Helper function to process the update of One2many or Many2many fields"""
        for field in data:
            if isinstance(data[field], dict):
                operations = []
                for operation in data[field]:
                    if operation == "push":
                        operations.extend(
                            (4, rec_id, 0)
                            for rec_id
                            in data[field].get("push")
                        )
                    elif operation == "pop":
                        operations.extend(
                            (3, rec_id, 0)
                            for rec_id
                            in data[field].get("pop")
                        )
                    elif operation == "delete":
                        operations.extend(
                            (2, rec_id, 0)
                            for rec_id
                            in data[field].get("delete")
                        )
                    else:
                        data[field].pop(operation)  # Invalid operation

                data[field] = operations
            elif isinstance(data[field], list) \
                    and all([isinstance(x, int) for x in data[field]]):
                data[field] = [(6, 0, data[field])]  # Replace operation
            else:
                pass

        return data

    @api.model
    def validate_schema(self, rules, data):
        """Helper function to process the validation of the schema"""
        if rules:
            try:
                validated_data = rules.validate(data)
            except SchemaError as e:
                error_msg = self.format_schema_error_reponse(e)
                raise exceptions.ValidationError(error_msg)
        else:
            validated_data = data

        return validated_data
