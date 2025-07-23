
from odoo import registry


# Add request information to database for tracking, analysis
def log_request(api_endpoint, request_received, dbname, message, status='success'):
    """ Helper fucntion to log request into table - Use SQL query + new cursor
    :param api_endpoint:      Endpoint to log
    :param request_received:  Information received and needed to be log
    :param dbname:            Odoo database
    :param message:           Message to explain log request
    :param status:            Status of the log should be fail or success

    The New cursor is useful in the case that we raise  an exception as the default cursor will be rollback and the log the fail function won't be log
    """
    cr = registry(dbname).cursor()
    query = """INSERT INTO pci_api_handler_log
    (create_date, write_date, api_endpoint, request_received, state, message)
    VALUES (now() at time zone 'UTC', now() at time zone 'UTC', %s, %s, %s, %s)"""
    params = (api_endpoint, request_received, status, message,)

    try:
        cr.execute(query, params)
        cr.commit()
    except Exception:
        # retry
        try:
            cr = registry(dbname).cursor()
            cr.execute(query, params)
            cr.commit()
        except Exception:
            cr.close()
    finally:
        cr.close()

    return True
