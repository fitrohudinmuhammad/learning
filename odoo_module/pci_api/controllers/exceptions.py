class QueryFormatError(Exception):
    """Invalid Query Format."""


class JsonApiException(Exception):
    """ Exception to raise an JSON Api issue"""
    def __init__(self, msg, hint=None, code=400):
        """ Init
        :param self:
        :param msg:            Error string to explain the exeception.
        :param hint:           Extended description of the error occured - (optional) - default: None
        :param code:           HTTP code - (optional) - default: 400

        :return:               None.
        """
        self.msg = msg
        self.code = code
        self.hint = hint
        super(JsonApiException, self).__init__(msg, hint, code)
