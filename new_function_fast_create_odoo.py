@api.model
@api.returns('self', lambda value: value.id)
def fast_create(self, vals):
    self.check_access_rights('create')

    account_id = self._get_account(vals)
    balance = self._get_balance(vals)
    company_id = account_id.company_id

    vals.update({
        'company_id': company_id.id,
        'balance': balance,
        'debit_cash_basis': vals.get('debit'),
        'credit_cash_basis': vals.get('credit'),
        'balance_cash_basis': vals.get('balance'),
        'company_currency_id': company_id.currency_id.id,
        'tax_base_amount': 0,
        'user_type_id': account_id.user_type_id.id

    })

    # add missing defaults, and drop fields that may not be set by user
    vals = self._add_missing_default_values(vals)
    pop_fields = ['parent_left', 'parent_right']
    if self._log_access:
        pop_fields.extend(MAGIC_COLUMNS)
    for field in pop_fields:
        vals.pop(field, None)

    # split up fields into old-style and pure new-style ones
    old_vals, new_vals, unknown = {}, {}, []
    for key, val in vals.items():
        field = self._fields.get(key)
        if field:
            if field.store or field.inherited:
                old_vals[key] = val
            if field.inverse and not field.inherited:
                new_vals[key] = val
        else:
            unknown.append(key)

    if unknown:
        _logger.warning("%s.create() includes unknown fields: %s", self._name, ', '.join(sorted(unknown)))

    # create record with old-style fields
    record = self.browse(self._fast_create(old_vals))

    return record

@api.model
def _fast_create(self, vals):
    # data of parent records to create or update, by model
    tocreate = {
        parent_model: {'id': vals.pop(parent_field, None)}
        for parent_model, parent_field in self._inherits.items()
    }

    # list of column assignments defined as tuples like:
    #   (column_name, format_string, column_value)
    #   (column_name, sql_formula)
    # Those tuples will be used by the string formatting for the INSERT
    # statement below.
    updates = [
        ('id', "nextval('%s')" % self._sequence),
    ]

    upd_todo = []
    unknown_fields = []
    protected_fields = []
    for name, val in list(vals.items()):
        field = self._fields.get(name)
        if not field:
            unknown_fields.append(name)
            del vals[name]
        elif field.inherited:
            tocreate[field.related_field.model_name][name] = val
            del vals[name]
        elif not field.store:
            del vals[name]
        elif field.inverse:
            protected_fields.append(field)
    if unknown_fields:
        _logger.warning('No such field(s) in model %s: %s.', self._name, ', '.join(unknown_fields))

    # create or update parent records
    for parent_model, parent_vals in tocreate.items():
        parent_id = parent_vals.pop('id')
        if not parent_id:
            parent_id = self.env[parent_model].create(parent_vals).id
        else:
            self.env[parent_model].browse(parent_id).write(parent_vals)
        vals[self._inherits[parent_model]] = parent_id

    # set boolean fields to False by default (to make search more powerful)
    for name, field in self._fields.items():
        if field.type == 'boolean' and field.store and name not in vals:
            vals[name] = False

    # determine SQL values
    self = self.browse()
    for name, val in vals.items():
        field = self._fields[name]
        if field.store and field.column_type:
            column_val = field.convert_to_column(val, self, vals)
            updates.append((name, field.column_format, column_val))
        else:
            upd_todo.append(name)

        if hasattr(field, 'selection') and val:
            self._check_selection_field_value(name, val)

    if self._log_access:
        updates.append(('create_uid', '%s', self._uid))
        updates.append(('write_uid', '%s', self._uid))
        updates.append(('create_date', "(now() at time zone 'UTC')"))
        updates.append(('write_date', "(now() at time zone 'UTC')"))

    # insert a row for this record
    cr = self._cr
    query = """INSERT INTO "%s" (%s) VALUES(%s) RETURNING id""" % (
        self._table,
        ', '.join('"%s"' % u[0] for u in updates),
        ', '.join(u[1] for u in updates),
    )
    cr.execute(query, tuple(u[2] for u in updates if len(u) > 2))

    # from now on, self is the new record
    id_new, = cr.fetchone()
    self = self.browse(id_new)

    if self._parent_store and not self._context.get('defer_parent_store_computation'):
        if self.pool._init:
            self.pool._init_parent[self._name] = True
        else:
            parent_val = vals.get(self._parent_name)
            if parent_val:
                # determine parent_left: it comes right after the
                # parent_right of its closest left sibling
                pleft = None
                cr.execute("SELECT parent_right FROM %s WHERE %s=%%s ORDER BY %s" % \
                            (self._table, self._parent_name, self._parent_order),
                            (parent_val,))
                for (pright,) in cr.fetchall():
                    if not pright:
                        break
                    pleft = pright + 1
                if not pleft:
                    # this is the leftmost child of its parent
                    cr.execute("SELECT parent_left FROM %s WHERE id=%%s" % self._table, (parent_val,))
                    pleft = cr.fetchone()[0] + 1
            else:
                # determine parent_left: it comes after all top-level parent_right
                cr.execute("SELECT MAX(parent_right) FROM %s" % self._table)
                pleft = (cr.fetchone()[0] or 0) + 1

            # make some room for the new node, and insert it in the MPTT
            cr.execute("UPDATE %s SET parent_left=parent_left+2 WHERE parent_left>=%%s" % self._table,
                        (pleft,))
            cr.execute("UPDATE %s SET parent_right=parent_right+2 WHERE parent_right>=%%s" % self._table,
                        (pleft,))
            cr.execute("UPDATE %s SET parent_left=%%s, parent_right=%%s WHERE id=%%s" % self._table,
                        (pleft, pleft + 1, id_new))
            self.invalidate_cache(['parent_left', 'parent_right'])

    self.check_access_rule('create')

    return id_new