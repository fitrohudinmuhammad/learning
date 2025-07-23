DROP table IF EXISTS preparation_table;
CREATE TABLE IF NOT EXISTS preparation_table(
    id bigserial,
    order_fee_id varchar,
    contract_number varchar,
    loan_purpose varchar,
    funding_type varchar,
    branch varchar,
    mca_number varchar,
    debtor_id varchar,
    debtor_name varchar,
    plat_number varchar,
    channel varchar,
    isrestructure varchar,
    istest varchar,
    order_id varchar,
    order_date varchar,
    start_date varchar,
    end_date varchar,
    order_type varchar,
    sub_order_type varchar,
    fee_type varchar,
    account_no varchar,
    payment_channel varchar,
    amount varchar,
    description varchar,
    mark_as_done boolean default false,
    filename varchar,
    create_date timestamp default now()
)partition by list(mark_as_done);

CREATE TABLE IF NOT EXISTS preparation_table_new_row PARTITION OF preparation_table FOR VALUES IN(FALSE);
CREATE TABLE IF NOT EXISTS preparation_table_archive PARTITION OF preparation_table FOR VALUES IN(TRUE);

DROP table IF EXISTS aggregation_table;
CREATE TABLE IF NOT EXISTS aggregation_table(
    id bigserial, -- middleware_id
    order_fee_id varchar,
    contract_number varchar,
    loan_purpose varchar,
    funding_type varchar,
    branch varchar,
    mca_number varchar,
    debtor_id varchar,
    debtor_name varchar,
    plat_number varchar,
    channel varchar,
    isrestructure boolean,
    istest boolean,
    order_id varchar,
    order_date timestamp,
    start_date timestamp,
    end_date timestamp,
    order_type varchar,
    sub_order_type varchar,
    fee_type varchar,
    account_no varchar,
    payment_channel varchar,
    amount float,
    description varchar,

    is_create boolean default true,
    is_update boolean default false,
    filename varchar,
    create_date timestamp default now(),
    stage int default 1,
    unique(order_fee_id)
);

CREATE INDEX IF NOT EXISTS aggregation_table_order_fee_id_idx ON aggregation_table(order_fee_id);
CREATE INDEX IF NOT EXISTS aggregation_table_contract_number_idx ON aggregation_table(contract_number);
CREATE INDEX IF NOT EXISTS aggregation_table_branch_idx ON aggregation_table(branch);
CREATE INDEX IF NOT EXISTS aggregation_table_debtor_name_idx ON aggregation_table(debtor_name);
CREATE INDEX IF NOT EXISTS aggregation_table_plat_number_idx ON aggregation_table(plat_number);
CREATE INDEX IF NOT EXISTS aggregation_table_channel_idx ON aggregation_table(channel);
CREATE INDEX IF NOT EXISTS aggregation_table_order_id_idx ON aggregation_table(order_id);
CREATE INDEX IF NOT EXISTS aggregation_table_order_date_idx ON aggregation_table(order_date);
CREATE INDEX IF NOT EXISTS aggregation_table_start_date_idx ON aggregation_table(start_date);
CREATE INDEX IF NOT EXISTS aggregation_table_end_date_idx ON aggregation_table(end_date);
CREATE INDEX IF NOT EXISTS aggregation_table_fee_type_idx ON aggregation_table(fee_type);
CREATE INDEX IF NOT EXISTS aggregation_table_account_no_idx ON aggregation_table(account_no);
CREATE INDEX IF NOT EXISTS aggregation_table_payment_channel_idx ON aggregation_table(payment_channel);
CREATE INDEX IF NOT EXISTS aggregation_table_filename_id_idx ON aggregation_table(filename);
CREATE INDEX IF NOT EXISTS aggregation_table_create_date_id_idx ON aggregation_table(create_date);
CREATE INDEX IF NOT EXISTS aggregation_table_stage_idx ON aggregation_table(stage);
CREATE INDEX IF NOT EXISTS aggregation_table_is_create_idx ON aggregation_table(is_create);
CREATE INDEX IF NOT EXISTS aggregation_table_is_update_idx ON aggregation_table(is_update);

ALTER TABLE leasing_contract_line ADD COLUMN IF NOT EXISTS middleware_id int;
ALTER TABLE leasing_contract_payment ADD COLUMN IF NOT EXISTS middleware_id int;