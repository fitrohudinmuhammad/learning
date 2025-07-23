from odoo import models, fields, api, _


class ResCompany(models.Model):
    _inherit = "res.company"

    @api.model
    def _auto_init(self):
        if self.env.user.company_id.ftp_active or self.env.user.company_id.sftp_active:
            if self.env.user.company_id.table_name
                table_name = self.env.user.company_id.table_name
                self.env.cr.execute("""
                    CREATE TABLE IF NOT EXISTS %s(
                        id bigserial,
                        order_fee_id bigint,
                        contract_number varchar,
                        status varchar,
                        loan_purpose varchar,
                        funding_type varchar,
                        branch varchar,
                        debtor_name varchar,
                        plat_number varchar,
                        order_class varchar,
                        isrestructure boolean,
                        istest boolean,
                        order_id varchar,
                        order_date date,
                        order_type varchar,
                        sub_order_type varchar,
                        fee_type varchar,
                        amount float,
                        description varchar,
                        mark_as_done boolean default false,
                        filename varchar,
                        create_date timestamp
                    )partition by list(mark_as_done);

                    CREATE TABLE IF NOT EXISTS %s PARTITION OF %s FOR VALUES IN(FALSE);
                    CREATE TABLE IF NOT EXISTS %s PARTITION OF %s FOR VALUES IN(TRUE);
                """ % (
                    table_name, table_name + '_new_row', table_name,
                    table_name + '_archive', table_name))

                self.env.cr.execute("""
                    CREATE INDEX IF NOT EXISTS %s_order_fee_id_idx ON %s(order_fee_id);
                    CREATE INDEX IF NOT EXISTS %s_contract_number_idx ON %s(contract_number);
                    CREATE INDEX IF NOT EXISTS %s_branch_idx ON %s(branch);
                    CREATE INDEX IF NOT EXISTS %s_debtor_name_idx ON %s(debtor_name);
                    CREATE INDEX IF NOT EXISTS %s_plat_number_idx ON %s(plat_number);
                    CREATE INDEX IF NOT EXISTS %s_order_class_idx ON %s(order_class);
                    CREATE INDEX IF NOT EXISTS %s_order_id_idx ON %s(order_id);
                    CREATE INDEX IF NOT EXISTS %s_order_type_idx ON %s(order_type);
                    CREATE INDEX IF NOT EXISTS %s_order_date_idx ON %s(order_date);
                    CREATE INDEX IF NOT EXISTS %s_fee_type_idx ON %s(fee_type);
                    CREATE INDEX IF NOT EXISTS %s_filename_id_idx ON %s(filename);
                    CREATE INDEX IF NOT EXISTS %s_create_date_id_idx ON %s(create_date);
                """ % (
                    table_name, table_name, table_name, table_name, table_name,
                    table_name, table_name, table_name, table_name, table_name,
                    table_name, table_name, table_name, table_name, table_name,
                    table_name, table_name, table_name, table_name, table_name,
                    table_name, table_name, table_name, table_name))

                # self.env.cr.execute("""
                #     DROP FUNCTION IF EXISTS insert_into_table();
                #     CREATE OR REPLACE FUNCTION public.insert_into_table()
                #     RETURNS TRIGGER
                #     LANGUAGE plpgsql AS
                #     $$
                #         INSERT INTO %s (%s) values ('%s)
                #         ON CONFLICT (order_fee_id)
                #         DO NOTHING;
                #     $$;
                # """)
