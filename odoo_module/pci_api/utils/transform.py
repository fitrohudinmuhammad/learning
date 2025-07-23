from odoo import exceptions, _


def transform_field_value_into_id(model, field_name, field_value, operator="=", prepared_function=lambda r: r,
                                  force_create=False, raise_if_not_found=False, **params):
    ''' Helper function to find the record id from an other identifier
    This function is useful to make api more user friendly. We can for example as the client to provide the country code and we can find the country_id in Odoo

    :param self:                  Empty/multiple recordset of the model.
    :param model:                 Empty recordset of the model needed
    :param field_name:            Name of the field we are searching
    :param field_value:           Value of the field we are searching
    :param operator:              Operator use in the search - (optinal) - default: =
    :param prepared_function:     Function to sanitize the value before the search
    :param force_create:          False or function to create the record if not found
    :param raise_if_not_found:    Flag to raise an error if value not found
    :param params:                Other params key that can be given to the force_create function

    :return: record id
    '''
    sanitize_value = prepared_function(field_value)
    record = model.search([
        (field_name, operator, sanitize_value)], limit=1)
    if not record and raise_if_not_found:
        raise exceptions.ValidationError(
            _(f'Can not found {model._name} on field "{field_name}" with value "{field_value}"'))

    if record:
        return record.id

    if force_create:
        try:
            vals = getattr(model, force_create)(field_name=field_name, field_value=field_value, **params)
            created_rec = model.create(vals)
            return created_rec.id
        except Exception as e:
            raise exceptions.ValidationError(e)

    return None
