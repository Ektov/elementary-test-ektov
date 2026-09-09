{{ config(
    materialized='view',
    tags=['demo_showcase']
) }}

select
    payment_id::integer as payment_id,
    order_id::integer as order_id,
    lower(trim(payment_method))::varchar(50) as payment_method,
    nullif(amount::text, '')::numeric(12, 2) as amount,
    upper(trim(currency))::varchar(10) as currency,
    paid_at::timestamp as paid_at,
    _loaded_at::timestamp as loaded_at
-- Use ref() (not source) so Cosmos/Airflow create seed → staging dependencies
from {{ ref('raw_payments') }}
